import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../../inventory/data/services/inventory_ledger_writer.dart';
import '../../../inventory/domain/entities/inventory_movement.dart';
import '../../../inventory/domain/entities/inventory_transaction_type.dart';
import '../../domain/entities/goods_receipt.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/purchases_repository.dart';
import '../../domain/services/weighted_average_cost_calculator.dart';
import '../data_sources/purchases_local_data_source.dart';

class DriftPurchasesRepository implements PurchasesRepository {
  const DriftPurchasesRepository({
    required db.AppDatabase database,
    required PurchasesLocalDataSource localDataSource,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
    WeightedAverageCostCalculator costCalculator =
        const WeightedAverageCostCalculator(),
  }) : _database = database,
       _localDataSource = localDataSource,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock,
       _costCalculator = costCalculator;

  final db.AppDatabase _database;
  final PurchasesLocalDataSource _localDataSource;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;
  final WeightedAverageCostCalculator _costCalculator;

  InventoryLedgerWriter get _ledgerWriter =>
      InventoryLedgerWriter(idGenerator: _idGenerator);

  @override
  Stream<List<Supplier>> watchSuppliers({required BusinessContext context}) =>
      _localDataSource.watchSuppliers(organizationId: context.organizationId);

  @override
  Stream<List<PurchaseOrder>> watchPurchaseOrders({
    required BusinessContext context,
  }) => _localDataSource.watchPurchaseOrders(
    organizationId: context.organizationId,
    branchId: context.branchId,
  );

  @override
  Future<PurchaseOrder?> getPurchaseOrder({
    required BusinessContext context,
    required String purchaseOrderId,
  }) => _localDataSource.getPurchaseOrder(
    organizationId: context.organizationId,
    branchId: context.branchId,
    purchaseOrderId: purchaseOrderId,
  );

  @override
  Future<PurchaseOptions> getOptions({required BusinessContext context}) async {
    final suppliers =
        await (_database.select(_database.suppliers)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.normalizedName)]))
            .get();
    final products =
        await (_database.select(_database.products)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.normalizedName)]))
            .get();
    final locations =
        await (_database.select(_database.stockLocations)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(context.branchId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull() &
                    row.locationType.isNotValue('damaged'),
              )
              ..orderBy([
                (row) => OrderingTerm.desc(row.isDefault),
                (row) => OrderingTerm.asc(row.name),
              ]))
            .get();
    return PurchaseOptions(
      suppliers: suppliers
          .map((row) => (id: row.id, code: row.code, name: row.name))
          .toList(growable: false),
      products: products
          .map(
            (row) =>
                PurchaseProductOption(id: row.id, sku: row.sku, name: row.name),
          )
          .toList(growable: false),
      locations: locations
          .map((row) => ReceivingLocationOption(id: row.id, name: row.name))
          .toList(growable: false),
    );
  }

  @override
  Future<Result<String, Failure>> createSupplier({
    required BusinessContext context,
    required SupplierDraft draft,
  }) async {
    final operationId = draft.operationId ?? _idGenerator.newId();
    final duplicate = await _existingOperation(operationId);
    if (duplicate != null) {
      return duplicate.commandType == 'supplier.create'
          ? Result.success(duplicate.aggregateId)
          : const Result.failure(
              ConflictFailure('The operation ID belongs to another action.'),
            );
    }
    final code = draft.code.trim();
    final name = draft.name.trim();
    if (code.isEmpty || name.isEmpty || draft.paymentTermsDays < 0) {
      return const Result.failure(
        ValidationFailure(
          'Supplier code, name, and non-negative payment terms are required.',
        ),
      );
    }
    final primaryContacts = draft.contacts.where(
      (contact) => contact.isPrimary,
    );
    if (primaryContacts.length > 1 ||
        draft.contacts.any(
          (contact) =>
              contact.name.trim().isEmpty ||
              (_trimmed(contact.email) == null &&
                  _trimmed(contact.phone) == null),
        )) {
      return const Result.failure(
        ValidationFailure(
          'Contacts require a name and email or phone, with at most one primary contact.',
        ),
      );
    }
    final supplierId = _idGenerator.newId();
    final contactIds = [for (final _ in draft.contacts) _idGenerator.newId()];
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await database
            .into(database.suppliers)
            .insert(
              db.SuppliersCompanion.insert(
                id: supplierId,
                organizationId: context.organizationId,
                code: code,
                normalizedCode: _normalize(code),
                name: name,
                normalizedName: _normalize(name),
                taxIdentifier: Value(_trimmed(draft.taxIdentifier)),
                paymentTermsDays: Value(draft.paymentTermsDays),
                createdAt: now,
                updatedAt: now,
              ),
            );
        for (var index = 0; index < draft.contacts.length; index++) {
          final contact = draft.contacts[index];
          await database
              .into(database.supplierContacts)
              .insert(
                db.SupplierContactsCompanion.insert(
                  id: contactIds[index],
                  organizationId: context.organizationId,
                  supplierId: supplierId,
                  name: contact.name.trim(),
                  role: Value(_trimmed(contact.role)),
                  email: Value(_trimmed(contact.email)),
                  phone: Value(_trimmed(contact.phone)),
                  isPrimary: Value(contact.isPrimary),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
        return supplierId;
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.create,
        'supplier',
        supplierId,
        now,
        {'code': code, 'name': name},
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'supplier.create',
        'supplier',
        supplierId,
        now,
        {
          'id': supplierId,
          'code': code,
          'name': name,
          'taxIdentifier': _trimmed(draft.taxIdentifier),
          'paymentTermsDays': draft.paymentTermsDays,
          'contacts': [
            for (var index = 0; index < draft.contacts.length; index++)
              {
                'id': contactIds[index],
                'name': draft.contacts[index].name.trim(),
                'role': _trimmed(draft.contacts[index].role),
                'email': _trimmed(draft.contacts[index].email),
                'phone': _trimmed(draft.contacts[index].phone),
                'isPrimary': draft.contacts[index].isPrimary,
              },
          ],
          'createdAt': now.toIso8601String(),
        },
      ),
    );
  }

  @override
  Future<Result<void, Failure>> archiveSupplier({
    required BusinessContext context,
    required String supplierId,
    required int expectedVersion,
    String? operationId,
  }) async {
    final operation = operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateVoid(operation, 'supplier', supplierId);
    if (duplicate != null) return duplicate;
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final changed =
            await (database.update(database.suppliers)..where(
                  (row) =>
                      row.id.equals(supplierId) &
                      row.organizationId.equals(context.organizationId) &
                      row.version.equals(expectedVersion) &
                      row.deletedAt.isNull(),
                ))
                .write(
                  db.SuppliersCompanion(
                    isActive: const Value(false),
                    version: Value(expectedVersion + 1),
                    updatedAt: Value(now),
                    deletedAt: Value(now),
                  ),
                );
        if (changed != 1) throw _versionConflict;
      },
      auditEntry: _audit(
        context,
        operation,
        AuditActionType.delete,
        'supplier',
        supplierId,
        now,
        {'expectedVersion': expectedVersion},
      ),
      outboxCommand: _outbox(
        context,
        operation,
        'supplier.archive',
        'supplier',
        supplierId,
        now,
        {'id': supplierId, 'expectedVersion': expectedVersion},
      ),
    );
  }

  @override
  Future<Result<String, Failure>> createPurchaseOrder({
    required BusinessContext context,
    required PurchaseOrderDraft draft,
  }) async {
    final operationId = draft.operationId ?? _idGenerator.newId();
    final duplicate = await _existingOperation(operationId);
    if (duplicate != null) {
      return duplicate.commandType == 'purchase_order.create'
          ? Result.success(duplicate.aggregateId)
          : const Result.failure(
              ConflictFailure('The operation ID belongs to another action.'),
            );
    }
    if (draft.supplierId.trim().isEmpty || draft.lines.isEmpty) {
      return const Result.failure(
        ValidationFailure('A supplier and at least one item are required.'),
      );
    }
    final products = <String>{};
    if (draft.lines.any(
      (line) =>
          !products.add(line.productId) ||
          line.orderedQuantityMilli <= 0 ||
          line.unitCostMinor < 0 ||
          line.estimatedLandedCostMinor < 0,
    )) {
      return const Result.failure(
        ValidationFailure(
          'Purchase items must be unique with positive quantities and non-negative costs.',
        ),
      );
    }
    final orderId = _idGenerator.newId();
    final itemIds = [for (final _ in draft.lines) _idGenerator.newId()];
    final now = _clock.nowUtc();
    final branch = await _activeBranch(_database, context);
    if (branch == null) {
      return const Result.failure(
        AuthorizationFailure('The active branch is unavailable locally.'),
      );
    }
    final orderNumber = _documentNumber('PO', branch.code, now, orderId);
    final supplierDependency = await _latestAggregateOperation(
      'supplier',
      draft.supplierId,
    );
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _requireActiveSupplier(database, context, draft.supplierId);
        await database
            .into(database.purchaseOrders)
            .insert(
              db.PurchaseOrdersCompanion.insert(
                id: orderId,
                organizationId: context.organizationId,
                branchId: context.branchId,
                supplierId: draft.supplierId,
                orderNumber: orderNumber,
                status: PurchaseOrderStatus.draft.databaseValue,
                notes: Value(_trimmed(draft.notes)),
                expectedDeliveryAt: Value(draft.expectedDeliveryAt?.toUtc()),
                createdByUserId: context.actorUserId,
                createdAt: now,
                updatedAt: now,
              ),
            );
        for (var index = 0; index < draft.lines.length; index++) {
          final line = draft.lines[index];
          await _requireActiveProduct(database, context, line.productId);
          await database
              .into(database.purchaseOrderItems)
              .insert(
                db.PurchaseOrderItemsCompanion.insert(
                  id: itemIds[index],
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  purchaseOrderId: orderId,
                  productId: line.productId,
                  orderedQuantityMilli: line.orderedQuantityMilli,
                  unitCostMinor: Value(line.unitCostMinor),
                  estimatedLandedCostMinor: Value(
                    line.estimatedLandedCostMinor,
                  ),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
        return orderId;
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.create,
        'purchase_order',
        orderId,
        now,
        {'orderNumber': orderNumber, 'supplierId': draft.supplierId},
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'purchase_order.create',
        'purchase_order',
        orderId,
        now,
        {
          'id': orderId,
          'supplierId': draft.supplierId,
          'orderNumber': orderNumber,
          'notes': _trimmed(draft.notes),
          'expectedDeliveryAt': draft.expectedDeliveryAt
              ?.toUtc()
              .toIso8601String(),
          'lines': [
            for (var index = 0; index < draft.lines.length; index++)
              {
                'id': itemIds[index],
                'productId': draft.lines[index].productId,
                'orderedQuantityMilli': draft.lines[index].orderedQuantityMilli,
                'unitCostMinor': draft.lines[index].unitCostMinor,
                'estimatedLandedCostMinor':
                    draft.lines[index].estimatedLandedCostMinor,
              },
          ],
          'createdAt': now.toIso8601String(),
        },
        dependsOnOperationId: supplierDependency,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> submitPurchaseOrder({
    required BusinessContext context,
    required String purchaseOrderId,
    required int expectedVersion,
    String? operationId,
  }) => _transition(
    context: context,
    purchaseOrderId: purchaseOrderId,
    expectedVersion: expectedVersion,
    expectedStatuses: const {PurchaseOrderStatus.draft},
    nextStatus: PurchaseOrderStatus.submitted,
    commandType: 'purchase_order.submit',
    operationId: operationId,
  );

  @override
  Future<Result<void, Failure>> approvePurchaseOrder({
    required BusinessContext context,
    required String purchaseOrderId,
    required int expectedVersion,
    String? operationId,
  }) => _transition(
    context: context,
    purchaseOrderId: purchaseOrderId,
    expectedVersion: expectedVersion,
    expectedStatuses: const {PurchaseOrderStatus.submitted},
    nextStatus: PurchaseOrderStatus.approved,
    commandType: 'purchase_order.approve',
    operationId: operationId,
    approved: true,
  );

  @override
  Future<Result<void, Failure>> cancelPurchaseOrder({
    required BusinessContext context,
    required String purchaseOrderId,
    required int expectedVersion,
    required String reason,
    String? operationId,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      return const Result.failure(
        ValidationFailure('A cancellation reason is required.'),
      );
    }
    final operation = operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateVoid(
      operation,
      'purchase_order',
      purchaseOrderId,
    );
    if (duplicate != null) return duplicate;
    final now = _clock.nowUtc();
    final dependency = await _latestOutboxOperation(purchaseOrderId);
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final order = await _requireOrder(database, context, purchaseOrderId);
        if (order.version != expectedVersion) throw _versionConflict;
        final status = PurchaseOrderStatus.fromDatabase(order.status);
        if (status == PurchaseOrderStatus.received ||
            status == PurchaseOrderStatus.cancelled) {
          throw const ConflictFailure(
            'A completed or cancelled purchase order cannot be cancelled.',
          );
        }
        final items = await _items(database, order.id);
        for (final item in items) {
          final remaining =
              item.orderedQuantityMilli -
              item.receivedQuantityMilli -
              item.cancelledQuantityMilli;
          if (remaining > 0) {
            await (database.update(database.purchaseOrderItems)..where(
                  (row) =>
                      row.id.equals(item.id) & row.version.equals(item.version),
                ))
                .write(
                  db.PurchaseOrderItemsCompanion(
                    cancelledQuantityMilli: Value(
                      item.cancelledQuantityMilli + remaining,
                    ),
                    version: Value(item.version + 1),
                    updatedAt: Value(now),
                  ),
                );
          }
        }
        await _updateOrder(
          database,
          order,
          PurchaseOrderStatus.cancelled,
          now,
          cancellationReason: normalizedReason,
        );
      },
      auditEntry: _audit(
        context,
        operation,
        AuditActionType.update,
        'purchase_order',
        purchaseOrderId,
        now,
        {'event': 'cancelled', 'reason': normalizedReason},
      ),
      outboxCommand: _outbox(
        context,
        operation,
        'purchase_order.cancel',
        'purchase_order',
        purchaseOrderId,
        now,
        {
          'id': purchaseOrderId,
          'expectedVersion': expectedVersion,
          'reason': normalizedReason,
          'occurredAt': now.toIso8601String(),
        },
        dependsOnOperationId: dependency,
      ),
    );
  }

  @override
  Future<Result<String, Failure>> receivePurchaseOrder({
    required BusinessContext context,
    required String purchaseOrderId,
    required int expectedVersion,
    required GoodsReceiptDraft draft,
  }) async {
    final operationId = draft.operationId ?? _idGenerator.newId();
    final priorReceipt = await (_database.select(
      _database.goodsReceipts,
    )..where((row) => row.operationId.equals(operationId))).getSingleOrNull();
    if (priorReceipt != null) {
      return priorReceipt.purchaseOrderId == purchaseOrderId
          ? Result.success(priorReceipt.id)
          : const Result.failure(
              ConflictFailure('The operation ID belongs to another receipt.'),
            );
    }
    if (draft.stockLocationId.trim().isEmpty || draft.lines.isEmpty) {
      return const Result.failure(
        ValidationFailure('A receiving location and items are required.'),
      );
    }
    final uniqueItems = <String>{};
    if (draft.lines.any(
      (line) =>
          !uniqueItems.add(line.purchaseOrderItemId) ||
          line.receivedQuantityMilli <= 0 ||
          line.unitCostMinor < 0 ||
          line.freightCostMinor < 0 ||
          line.dutyCostMinor < 0 ||
          line.otherLandedCostMinor < 0,
    )) {
      return const Result.failure(
        ValidationFailure(
          'Receipt items must be unique with positive quantities and non-negative costs.',
        ),
      );
    }
    final receiptId = _idGenerator.newId();
    final inventoryTransactionId = _idGenerator.newId();
    final receiptItemIds = [for (final _ in draft.lines) _idGenerator.newId()];
    final now = _clock.nowUtc();
    final occurredAt = draft.receivedAt?.toUtc() ?? now;
    final branch = await _activeBranch(_database, context);
    if (branch == null) {
      return const Result.failure(
        AuthorizationFailure('The active branch is unavailable locally.'),
      );
    }
    final receiptNumber = _documentNumber('GR', branch.code, now, receiptId);
    final dependency = await _latestOutboxOperation(purchaseOrderId);
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final order = await _requireOrder(database, context, purchaseOrderId);
        if (order.version != expectedVersion) throw _versionConflict;
        final status = PurchaseOrderStatus.fromDatabase(order.status);
        if (status != PurchaseOrderStatus.approved &&
            status != PurchaseOrderStatus.partiallyReceived) {
          throw const ConflictFailure(
            'Only approved purchase orders can be received.',
          );
        }
        await _requireReceivingLocation(
          database,
          context,
          draft.stockLocationId,
        );
        final orderItems = await _items(database, purchaseOrderId);
        final itemsById = {for (final item in orderItems) item.id: item};
        final selectedItems = <db.PurchaseOrderItem>[];
        for (final line in draft.lines) {
          final item = itemsById[line.purchaseOrderItemId];
          if (item == null) {
            throw const AuthorizationFailure(
              'A receipt item is outside this purchase order.',
            );
          }
          final remaining =
              item.orderedQuantityMilli -
              item.receivedQuantityMilli -
              item.cancelledQuantityMilli;
          if (line.receivedQuantityMilli > remaining) {
            throw ValidationFailure(
              '${line.receivedQuantityMilli} exceeds the remaining ordered quantity of $remaining.',
            );
          }
          selectedItems.add(item);
        }
        final beforeBalances = <String, db.InventoryBalance?>{};
        for (final item in selectedItems) {
          beforeBalances[item.productId] =
              await (database.select(database.inventoryBalances)..where(
                    (row) =>
                        row.organizationId.equals(context.organizationId) &
                        row.branchId.equals(context.branchId) &
                        row.stockLocationId.equals(draft.stockLocationId) &
                        row.productId.equals(item.productId),
                  ))
                  .getSingleOrNull();
        }
        await _ledgerWriter.post(
          database: database,
          context: context,
          draft: InventoryMovementDraft(
            type: InventoryTransactionType.purchaseReceipt,
            reasonCode: 'purchase_receipt',
            notes: _trimmed(draft.notes),
            referenceType: 'goods_receipt',
            referenceId: receiptId,
            occurredAt: occurredAt,
            lines: [
              for (var index = 0; index < draft.lines.length; index++)
                InventoryMovementLineDraft(
                  stockLocationId: draft.stockLocationId,
                  productId: selectedItems[index].productId,
                  quantityDeltaMilli: draft.lines[index].receivedQuantityMilli,
                ),
            ],
          ),
          transactionId: inventoryTransactionId,
          operationId: '$operationId:inventory',
          now: now,
        );
        await database
            .into(database.goodsReceipts)
            .insert(
              db.GoodsReceiptsCompanion.insert(
                id: receiptId,
                organizationId: context.organizationId,
                branchId: context.branchId,
                purchaseOrderId: purchaseOrderId,
                supplierId: order.supplierId,
                stockLocationId: draft.stockLocationId,
                receiptNumber: receiptNumber,
                operationId: operationId,
                supplierDocumentNumber: Value(
                  _trimmed(draft.supplierDocumentNumber),
                ),
                notes: Value(_trimmed(draft.notes)),
                receivedByUserId: context.actorUserId,
                receivedAt: occurredAt,
                createdAt: now,
              ),
            );
        for (var index = 0; index < draft.lines.length; index++) {
          final line = draft.lines[index];
          final item = selectedItems[index];
          final previous = beforeBalances[item.productId];
          final landedUnitCost = _costCalculator.landedUnitCostMinor(
            quantityMilli: line.receivedQuantityMilli,
            unitCostMinor: line.unitCostMinor,
            freightCostMinor: line.freightCostMinor,
            dutyCostMinor: line.dutyCostMinor,
            otherLandedCostMinor: line.otherLandedCostMinor,
          );
          final averageCost = _costCalculator.weightedAverageCostMinor(
            currentQuantityMilli: previous?.onHandMilli ?? 0,
            currentAverageCostMinor: previous?.weightedAverageCostMinor ?? 0,
            receivedQuantityMilli: line.receivedQuantityMilli,
            receivedLandedUnitCostMinor: landedUnitCost,
          );
          await (database.update(database.inventoryBalances)..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(context.branchId) &
                    row.stockLocationId.equals(draft.stockLocationId) &
                    row.productId.equals(item.productId),
              ))
              .write(
                db.InventoryBalancesCompanion(
                  weightedAverageCostMinor: Value(averageCost),
                  updatedAt: Value(now),
                ),
              );
          await database
              .into(database.goodsReceiptItems)
              .insert(
                db.GoodsReceiptItemsCompanion.insert(
                  id: receiptItemIds[index],
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  goodsReceiptId: receiptId,
                  purchaseOrderItemId: item.id,
                  productId: item.productId,
                  inventoryTransactionId: inventoryTransactionId,
                  receivedQuantityMilli: line.receivedQuantityMilli,
                  unitCostMinor: line.unitCostMinor,
                  freightCostMinor: Value(line.freightCostMinor),
                  dutyCostMinor: Value(line.dutyCostMinor),
                  otherLandedCostMinor: Value(line.otherLandedCostMinor),
                  landedUnitCostMinor: landedUnitCost,
                  weightedAverageCostMinorAfter: averageCost,
                  createdAt: now,
                ),
              );
          final changed =
              await (database.update(database.purchaseOrderItems)..where(
                    (row) =>
                        row.id.equals(item.id) &
                        row.version.equals(item.version),
                  ))
                  .write(
                    db.PurchaseOrderItemsCompanion(
                      receivedQuantityMilli: Value(
                        item.receivedQuantityMilli + line.receivedQuantityMilli,
                      ),
                      version: Value(item.version + 1),
                      updatedAt: Value(now),
                    ),
                  );
          if (changed != 1) throw _versionConflict;
        }
        final updatedItems = await _items(database, purchaseOrderId);
        final remaining = updatedItems.fold<int>(
          0,
          (total, item) =>
              total +
              item.orderedQuantityMilli -
              item.receivedQuantityMilli -
              item.cancelledQuantityMilli,
        );
        await _updateOrder(
          database,
          order,
          remaining == 0
              ? PurchaseOrderStatus.received
              : PurchaseOrderStatus.partiallyReceived,
          now,
        );
        return receiptId;
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.create,
        'goods_receipt',
        receiptId,
        now,
        {'purchaseOrderId': purchaseOrderId, 'receiptNumber': receiptNumber},
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'purchase_order.receive',
        'purchase_order',
        purchaseOrderId,
        now,
        {
          'id': purchaseOrderId,
          'receiptId': receiptId,
          'inventoryTransactionId': inventoryTransactionId,
          'receiptNumber': receiptNumber,
          'expectedVersion': expectedVersion,
          'stockLocationId': draft.stockLocationId,
          'supplierDocumentNumber': _trimmed(draft.supplierDocumentNumber),
          'notes': _trimmed(draft.notes),
          'receivedAt': occurredAt.toIso8601String(),
          'lines': [
            for (var index = 0; index < draft.lines.length; index++)
              {
                'id': receiptItemIds[index],
                'purchaseOrderItemId': draft.lines[index].purchaseOrderItemId,
                'receivedQuantityMilli':
                    draft.lines[index].receivedQuantityMilli,
                'unitCostMinor': draft.lines[index].unitCostMinor,
                'freightCostMinor': draft.lines[index].freightCostMinor,
                'dutyCostMinor': draft.lines[index].dutyCostMinor,
                'otherLandedCostMinor': draft.lines[index].otherLandedCostMinor,
              },
          ],
        },
        dependsOnOperationId: dependency,
      ),
    );
  }

  Future<Result<void, Failure>> _transition({
    required BusinessContext context,
    required String purchaseOrderId,
    required int expectedVersion,
    required Set<PurchaseOrderStatus> expectedStatuses,
    required PurchaseOrderStatus nextStatus,
    required String commandType,
    String? operationId,
    bool approved = false,
  }) async {
    final operation = operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateVoid(
      operation,
      'purchase_order',
      purchaseOrderId,
    );
    if (duplicate != null) return duplicate;
    final now = _clock.nowUtc();
    final dependency = await _latestOutboxOperation(purchaseOrderId);
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final order = await _requireOrder(database, context, purchaseOrderId);
        if (order.version != expectedVersion) throw _versionConflict;
        final status = PurchaseOrderStatus.fromDatabase(order.status);
        if (!expectedStatuses.contains(status)) {
          throw ConflictFailure(
            '${nextStatus.label} is not valid from ${status.label}.',
          );
        }
        await _updateOrder(
          database,
          order,
          nextStatus,
          now,
          approvedByUserId: approved ? context.actorUserId : null,
        );
      },
      auditEntry: _audit(
        context,
        operation,
        AuditActionType.update,
        'purchase_order',
        purchaseOrderId,
        now,
        {'event': nextStatus.databaseValue},
      ),
      outboxCommand: _outbox(
        context,
        operation,
        commandType,
        'purchase_order',
        purchaseOrderId,
        now,
        {
          'id': purchaseOrderId,
          'expectedVersion': expectedVersion,
          'occurredAt': now.toIso8601String(),
        },
        dependsOnOperationId: dependency,
      ),
    );
  }

  Future<db.PurchaseOrder> _requireOrder(
    db.AppDatabase database,
    BusinessContext context,
    String purchaseOrderId,
  ) async {
    final order =
        await (database.select(database.purchaseOrders)..where(
              (row) =>
                  row.id.equals(purchaseOrderId) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId),
            ))
            .getSingleOrNull();
    if (order == null) {
      throw const AuthorizationFailure(
        'The purchase order is outside the active branch context.',
      );
    }
    return order;
  }

  Future<void> _updateOrder(
    db.AppDatabase database,
    db.PurchaseOrder order,
    PurchaseOrderStatus status,
    DateTime now, {
    String? approvedByUserId,
    String? cancellationReason,
  }) async {
    final changed =
        await (database.update(database.purchaseOrders)..where(
              (row) =>
                  row.id.equals(order.id) & row.version.equals(order.version),
            ))
            .write(
              db.PurchaseOrdersCompanion(
                status: Value(status.databaseValue),
                submittedAt: status == PurchaseOrderStatus.submitted
                    ? Value(now)
                    : const Value.absent(),
                approvedAt: status == PurchaseOrderStatus.approved
                    ? Value(now)
                    : const Value.absent(),
                approvedByUserId: approvedByUserId == null
                    ? const Value.absent()
                    : Value(approvedByUserId),
                cancelledAt: status == PurchaseOrderStatus.cancelled
                    ? Value(now)
                    : const Value.absent(),
                cancellationReason: cancellationReason == null
                    ? const Value.absent()
                    : Value(cancellationReason),
                version: Value(order.version + 1),
                updatedAt: Value(now),
              ),
            );
    if (changed != 1) throw _versionConflict;
  }

  Future<List<db.PurchaseOrderItem>> _items(
    db.AppDatabase database,
    String purchaseOrderId,
  ) => (database.select(
    database.purchaseOrderItems,
  )..where((row) => row.purchaseOrderId.equals(purchaseOrderId))).get();

  Future<void> _requireActiveSupplier(
    db.AppDatabase database,
    BusinessContext context,
    String supplierId,
  ) async {
    final supplier =
        await (database.select(database.suppliers)..where(
              (row) =>
                  row.id.equals(supplierId) &
                  row.organizationId.equals(context.organizationId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (supplier == null) {
      throw const AuthorizationFailure(
        'The supplier is unavailable in this organization.',
      );
    }
  }

  Future<void> _requireActiveProduct(
    db.AppDatabase database,
    BusinessContext context,
    String productId,
  ) async {
    final product =
        await (database.select(database.products)..where(
              (row) =>
                  row.id.equals(productId) &
                  row.organizationId.equals(context.organizationId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (product == null) {
      throw const AuthorizationFailure(
        'A purchase item is unavailable in this organization.',
      );
    }
  }

  Future<void> _requireReceivingLocation(
    db.AppDatabase database,
    BusinessContext context,
    String locationId,
  ) async {
    final location =
        await (database.select(database.stockLocations)..where(
              (row) =>
                  row.id.equals(locationId) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull() &
                  row.locationType.isNotValue('damaged'),
            ))
            .getSingleOrNull();
    if (location == null) {
      throw const AuthorizationFailure(
        'The receiving location is unavailable in this branch.',
      );
    }
  }

  Future<db.Branche?> _activeBranch(
    db.AppDatabase database,
    BusinessContext context,
  ) =>
      (database.select(database.branches)..where(
            (row) =>
                row.id.equals(context.branchId) &
                row.organizationId.equals(context.organizationId) &
                row.isActive.equals(true) &
                row.deletedAt.isNull(),
          ))
          .getSingleOrNull();

  Future<db.SyncOutboxEntry?> _existingOperation(String operationId) =>
      (_database.select(
        _database.syncOutboxEntries,
      )..where((row) => row.operationId.equals(operationId))).getSingleOrNull();

  Future<Result<void, Failure>?> _duplicateVoid(
    String operationId,
    String aggregateType,
    String aggregateId,
  ) async {
    final operation = await _existingOperation(operationId);
    if (operation == null) return null;
    return operation.aggregateType == aggregateType &&
            operation.aggregateId == aggregateId
        ? const Result.success(null)
        : const Result.failure(
            ConflictFailure('The operation ID belongs to another action.'),
          );
  }

  Future<String?> _latestOutboxOperation(String purchaseOrderId) async {
    return _latestAggregateOperation('purchase_order', purchaseOrderId);
  }

  Future<String?> _latestAggregateOperation(
    String aggregateType,
    String aggregateId,
  ) async {
    final rows =
        await (_database.select(_database.syncOutboxEntries)
              ..where(
                (row) =>
                    row.aggregateType.equals(aggregateType) &
                    row.aggregateId.equals(aggregateId),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(1))
            .get();
    return rows.firstOrNull?.operationId;
  }

  AuditLogEntry _audit(
    BusinessContext context,
    String operationId,
    AuditActionType action,
    String entityName,
    String entityId,
    DateTime now,
    Map<String, Object?> metadata,
  ) => AuditLogEntry(
    id: _idGenerator.newId(),
    operationId: operationId,
    organizationId: context.organizationId,
    branchId: context.branchId,
    actorUserId: context.actorUserId,
    actionType: action,
    entityName: entityName,
    entityId: entityId,
    metadata: metadata,
    createdAt: now,
  );

  OutboxCommand _outbox(
    BusinessContext context,
    String operationId,
    String commandType,
    String aggregateType,
    String aggregateId,
    DateTime now,
    Map<String, Object?> payload, {
    String? dependsOnOperationId,
  }) => OutboxCommand(
    operationId: operationId,
    organizationId: context.organizationId,
    branchId: context.branchId,
    actorUserId: context.actorUserId,
    commandType: commandType,
    aggregateType: aggregateType,
    aggregateId: aggregateId,
    dependsOnOperationId: dependsOnOperationId,
    payload: payload,
    createdAt: now,
  );
}

const _versionConflict = ConflictFailure(
  'The purchase record changed after it was opened. Refresh and retry.',
);

String _normalize(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

String? _trimmed(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _documentNumber(
  String prefix,
  String branchCode,
  DateTime now,
  String id,
) {
  final date =
      '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  final cleanedId = id.replaceAll('-', '').toUpperCase().padLeft(8, '0');
  final suffix = cleanedId.substring(cleanedId.length - 8);
  return '$prefix-${branchCode.toUpperCase()}-$date-$suffix';
}
