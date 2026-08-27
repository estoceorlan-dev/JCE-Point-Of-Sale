import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart'
    hide Payment, Sale, SaleItem;
import '../../../../core/database/app_database.dart'
    as db
    show Branche, Register, Sale, Shift;
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
import '../../domain/entities/cart.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_product.dart';
import '../../domain/entities/sale_status.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/value_objects/cart_pricing.dart';
import '../data_sources/sales_local_data_source.dart';
import '../services/receipt_number_allocator.dart';

class DriftSalesRepository implements SalesRepository {
  const DriftSalesRepository({
    required AppDatabase database,
    required SalesLocalDataSource localDataSource,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _database = database,
       _localDataSource = localDataSource,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock;

  final AppDatabase _database;
  final SalesLocalDataSource _localDataSource;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  InventoryLedgerWriter get _ledgerWriter =>
      InventoryLedgerWriter(idGenerator: _idGenerator);

  ReceiptNumberAllocator get _receiptAllocator =>
      ReceiptNumberAllocator(idGenerator: _idGenerator);

  @override
  Stream<List<SaleProduct>> watchSaleProducts({
    required BusinessContext context,
    required String search,
  }) {
    return _localDataSource.watchSaleProducts(
      organizationId: context.organizationId,
      branchId: context.branchId,
      search: search,
      now: _clock.nowUtc(),
    );
  }

  @override
  Stream<List<SaleRecord>> watchRecentSales({
    required BusinessContext context,
  }) {
    return _localDataSource.watchRecentSales(
      organizationId: context.organizationId,
      branchId: context.branchId,
    );
  }

  @override
  Future<SaleRecord?> getSale({
    required BusinessContext context,
    required String saleId,
  }) {
    return _localDataSource.getSale(
      organizationId: context.organizationId,
      branchId: context.branchId,
      saleId: saleId,
    );
  }

  @override
  Future<DiscountPolicy?> getDiscountPolicy({
    required BusinessContext context,
  }) async {
    final branch = await _findBranch(_database, context);
    if (branch == null) return null;
    return DiscountPolicy(
      approvalThresholdBasisPoints: branch.discountApprovalThresholdBasisPoints,
    );
  }

  @override
  Future<Result<void, Failure>> configureDiscountPolicy({
    required BusinessContext context,
    required DiscountPolicy policy,
  }) async {
    final threshold = policy.approvalThresholdBasisPoints;
    if (threshold != null && (threshold < 0 || threshold > 10000)) {
      return const Result.failure(
        ValidationFailure('Discount approval threshold must be 0–100 percent.'),
      );
    }
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final changed =
            await (database.update(database.branches)..where(
                  (row) =>
                      row.id.equals(context.branchId) &
                      row.organizationId.equals(context.organizationId),
                ))
                .write(
                  BranchesCompanion(
                    discountApprovalThresholdBasisPoints: Value(threshold),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) {
          throw const AuthorizationFailure(
            'The active branch is not available locally.',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'branch_discount_policy',
        entityId: context.branchId,
        metadata: {'approvalThresholdBasisPoints': threshold},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        aggregateId: context.branchId,
        commandType: 'branch.discount_policy.update',
        aggregateType: 'branch',
        payload: {'approvalThresholdBasisPoints': threshold},
        now: now,
      ),
    );
  }

  @override
  Future<Result<CheckoutResult, Failure>> checkout({
    required BusinessContext context,
    required CheckoutDraft draft,
    String? discountApprovedByUserId,
  }) async {
    final operationId = draft.operationId ?? _idGenerator.newId();
    final existing = await _saleForOperation(context, operationId);
    if (existing != null) {
      return Result.success(
        CheckoutResult(
          saleId: existing.id,
          receiptNumber: existing.receiptNumber ?? 'Pending',
        ),
      );
    }
    late final CartPricing pricing;
    late final PaymentReconciliation reconciliation;
    try {
      final canonicalCart = await _canonicalCart(context, draft.cart);
      pricing = CartPricingCalculator.calculate(canonicalCart);
      reconciliation = PaymentCalculator.reconcile(
        totalMinor: pricing.totalMinor,
        tenders: draft.tenders,
      );
      _validateUniqueProducts(pricing);
    } on Failure catch (failure) {
      return Result.failure(failure);
    }
    final saleId = _idGenerator.newId();
    final inventoryTransactionId = _idGenerator.newId();
    final itemIds = [for (final _ in pricing.lines) _idGenerator.newId()];
    final now = _clock.nowUtc();
    final mutation = await _localMutationTransaction.execute(
      businessWrite: (database) async {
        final scope = await _resolveRegisterAndShift(
          database,
          context,
          draft.deviceId,
        );
        final branch = scope.branch;
        final threshold = branch.discountApprovalThresholdBasisPoints;
        if (threshold != null &&
            pricing.discountMinor * 10000 > pricing.subtotalMinor * threshold &&
            discountApprovedByUserId == null) {
          throw const AuthorizationFailure(
            'This discount exceeds the branch approval threshold.',
            code: 'sale-discount-approval-required',
          );
        }
        final receiptNumber = await _receiptAllocator.allocate(
          database: database,
          context: context,
          register: scope.register,
          branchCode: branch.code,
          now: now,
        );
        await _ledgerWriter.post(
          database: database,
          context: context,
          draft: InventoryMovementDraft(
            type: InventoryTransactionType.sale,
            referenceType: 'sale',
            referenceId: saleId,
            occurredAt: now,
            lines: [
              for (final priced in pricing.lines)
                InventoryMovementLineDraft(
                  stockLocationId: priced.line.product.stockLocationId,
                  productId: priced.line.product.id,
                  quantityDeltaMilli: -priced.line.quantityMilli,
                  expectedBalanceVersion: priced.line.product.inventoryVersion,
                ),
            ],
          ),
          transactionId: inventoryTransactionId,
          operationId: '$operationId:inventory',
          now: now,
        );
        await database
            .into(database.sales)
            .insert(
              SalesCompanion.insert(
                id: saleId,
                organizationId: context.organizationId,
                branchId: context.branchId,
                registerId: scope.register.id,
                shiftId: Value(scope.shift?.id),
                inventoryTransactionId: Value(inventoryTransactionId),
                operationId: operationId,
                receiptNumber: Value(receiptNumber),
                status: Value(SaleStatus.completed.databaseValue),
                cashierUserId: context.actorUserId,
                subtotalMinor: Value(pricing.subtotalMinor),
                discountMinor: Value(pricing.discountMinor),
                taxMinor: Value(pricing.taxMinor),
                totalMinor: Value(pricing.totalMinor),
                tenderedMinor: Value(reconciliation.tenderedMinor),
                changeMinor: Value(reconciliation.changeMinor),
                discountApprovedByUserId: Value(discountApprovedByUserId),
                discountApprovedAt: Value(
                  discountApprovedByUserId == null ? null : now,
                ),
                completedAt: Value(now),
                createdAt: now,
                updatedAt: now,
              ),
            );
        for (var index = 0; index < pricing.lines.length; index++) {
          final priced = pricing.lines[index];
          final product = priced.line.product;
          await database
              .into(database.saleItems)
              .insert(
                SaleItemsCompanion.insert(
                  id: itemIds[index],
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  saleId: saleId,
                  productId: product.id,
                  stockLocationId: product.stockLocationId,
                  lineNumber: index + 1,
                  productNameSnapshot: product.name,
                  skuSnapshot: product.sku,
                  barcodeSnapshot: Value(product.primaryBarcode),
                  unitNameSnapshot: product.unitName,
                  quantityMilli: priced.line.quantityMilli,
                  unitPriceMinorSnapshot: product.unitPriceMinor,
                  unitCostMinorSnapshot: product.unitCostMinor,
                  taxRateBasisPointsSnapshot: product.taxRateBasisPoints,
                  taxInclusiveSnapshot: product.taxInclusive,
                  grossAmountMinor: priced.grossAmountMinor,
                  discountAmountMinor: priced.discountAmountMinor,
                  netAmountMinor: priced.netAmountMinor,
                  taxAmountMinor: priced.taxAmountMinor,
                  totalAmountMinor: priced.totalAmountMinor,
                  createdAt: now,
                ),
              );
          if (priced.itemDiscountMinor > 0) {
            await _insertDiscount(
              database: database,
              context: context,
              saleId: saleId,
              saleItemId: itemIds[index],
              scope: 'item',
              amountMinor: priced.itemDiscountMinor,
              reason: priced.line.discountReason!,
              approvedByUserId: discountApprovedByUserId,
              now: now,
            );
          }
        }
        if (draft.cart.saleDiscountMinor > 0) {
          await _insertDiscount(
            database: database,
            context: context,
            saleId: saleId,
            scope: 'sale',
            amountMinor: draft.cart.saleDiscountMinor,
            reason: draft.cart.saleDiscountReason!,
            approvedByUserId: discountApprovedByUserId,
            now: now,
          );
        }
        for (final payment in reconciliation.payments) {
          await database
              .into(database.payments)
              .insert(
                PaymentsCompanion.insert(
                  id: _idGenerator.newId(),
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  saleId: saleId,
                  shiftId: Value(scope.shift?.id),
                  paymentMethod: payment.method.databaseValue,
                  tenderedAmountMinor: payment.tenderedAmountMinor,
                  appliedAmountMinor: payment.appliedAmountMinor,
                  changeAmountMinor: Value(payment.changeAmountMinor),
                  reference: Value(_trimmedOrNull(payment.reference)),
                  createdAt: now,
                ),
              );
        }
        return CheckoutResult(saleId: saleId, receiptNumber: receiptNumber);
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.sale,
        entityName: 'sale',
        entityId: saleId,
        metadata: {
          'subtotalMinor': pricing.subtotalMinor,
          'discountMinor': pricing.discountMinor,
          'taxMinor': pricing.taxMinor,
          'totalMinor': pricing.totalMinor,
          'changeMinor': reconciliation.changeMinor,
          'lineCount': pricing.lines.length,
          'discountApprovedByUserId': discountApprovedByUserId,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'sale.complete',
        aggregateType: 'sale',
        aggregateId: saleId,
        payload: _salePayload(
          saleId: saleId,
          inventoryTransactionId: inventoryTransactionId,
          pricing: pricing,
          reconciliation: reconciliation,
          deviceId: draft.deviceId,
          approvedByUserId: discountApprovedByUserId,
          saleDiscountReason: draft.cart.saleDiscountReason,
          now: now,
        ),
        now: now,
      ),
    );
    if (mutation.isFailure) {
      final concurrent = await _saleForOperation(context, operationId);
      if (concurrent != null) {
        return Result.success(
          CheckoutResult(
            saleId: concurrent.id,
            receiptNumber: concurrent.receiptNumber ?? 'Pending',
          ),
        );
      }
    }
    return mutation;
  }

  Future<Cart> _canonicalCart(BusinessContext context, Cart cart) async {
    final lines = <CartLine>[];
    for (final line in cart.lines) {
      final product = await _localDataSource.getSaleProduct(
        organizationId: context.organizationId,
        branchId: context.branchId,
        productId: line.product.id,
        now: _clock.nowUtc(),
      );
      if (product == null || product.unitPriceMinor <= 0) {
        throw ValidationFailure(
          '${line.product.name} is no longer configured for sale on this branch.',
        );
      }
      lines.add(
        CartLine(
          product: product,
          quantityMilli: line.quantityMilli,
          itemDiscountMinor: line.itemDiscountMinor,
          discountReason: line.discountReason,
        ),
      );
    }
    return Cart(
      lines: lines,
      saleDiscountMinor: cart.saleDiscountMinor,
      saleDiscountReason: cart.saleDiscountReason,
    );
  }

  Future<_CheckoutScope> _resolveRegisterAndShift(
    AppDatabase database,
    BusinessContext context,
    String deviceId,
  ) async {
    final normalizedDeviceId = deviceId.trim();
    final register =
        await (database.select(database.registers)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.assignedDeviceId.equals(normalizedDeviceId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (register == null) {
      throw const AuthorizationFailure(
        'Assign this device to an active register before checkout.',
        code: 'register-device-mismatch',
      );
    }
    final branch = await _findBranch(database, context);
    if (branch == null) {
      throw const AuthorizationFailure(
        'The active branch is not available locally.',
      );
    }
    final shift =
        await (database.select(database.shifts)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.registerId.equals(register.id) &
                  row.deviceId.equals(normalizedDeviceId) &
                  row.status.equals('open'),
            ))
            .getSingleOrNull();
    if (shift == null && !branch.allowSalesWithoutOpenShift) {
      throw const AuthorizationFailure(
        'Open a shift on this register before checkout.',
        code: 'open-shift-required',
      );
    }
    if (shift != null && shift.openedByUserId != context.actorUserId) {
      throw const AuthorizationFailure(
        'This register has a shift opened by another user.',
        code: 'shift-owner-mismatch',
      );
    }
    return _CheckoutScope(branch: branch, register: register, shift: shift);
  }

  Future<void> _insertDiscount({
    required AppDatabase database,
    required BusinessContext context,
    required String saleId,
    required String scope,
    required int amountMinor,
    required String reason,
    required DateTime now,
    String? saleItemId,
    String? approvedByUserId,
  }) async {
    await database
        .into(database.saleDiscounts)
        .insert(
          SaleDiscountsCompanion.insert(
            id: _idGenerator.newId(),
            organizationId: context.organizationId,
            branchId: context.branchId,
            saleId: saleId,
            saleItemId: Value(saleItemId),
            discountScope: scope,
            amountMinor: amountMinor,
            reason: reason.trim(),
            approvedByUserId: Value(approvedByUserId),
            approvedAt: Value(approvedByUserId == null ? null : now),
            createdAt: now,
          ),
        );
  }

  Future<db.Sale?> _saleForOperation(
    BusinessContext context,
    String operationId,
  ) {
    return (_database.select(_database.sales)..where(
          (row) =>
              row.organizationId.equals(context.organizationId) &
              row.operationId.equals(operationId),
        ))
        .getSingleOrNull();
  }

  void _validateUniqueProducts(CartPricing pricing) {
    final keys = <String>{};
    for (final priced in pricing.lines) {
      final product = priced.line.product;
      if (!keys.add('${product.stockLocationId}:${product.id}')) {
        throw const ValidationFailure(
          'Combine duplicate products into one cart line.',
        );
      }
    }
  }

  AuditLogEntry _audit({
    required BusinessContext context,
    required String operationId,
    required AuditActionType action,
    required String entityName,
    required String entityId,
    required Map<String, Object?> metadata,
    required DateTime now,
  }) {
    return AuditLogEntry(
      id: _idGenerator.newId(),
      operationId: operationId,
      organizationId: context.organizationId,
      actorUserId: context.actorUserId,
      branchId: context.branchId,
      actionType: action,
      entityName: entityName,
      entityId: entityId,
      metadata: metadata,
      createdAt: now,
    );
  }

  OutboxCommand _outbox({
    required BusinessContext context,
    required String operationId,
    required String commandType,
    required String aggregateType,
    required String aggregateId,
    required Map<String, Object?> payload,
    required DateTime now,
  }) {
    return OutboxCommand(
      operationId: operationId,
      organizationId: context.organizationId,
      branchId: context.branchId,
      actorUserId: context.actorUserId,
      commandType: commandType,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      payload: payload,
      createdAt: now,
    );
  }

  Map<String, Object?> _salePayload({
    required String saleId,
    required String inventoryTransactionId,
    required CartPricing pricing,
    required PaymentReconciliation reconciliation,
    required String deviceId,
    required DateTime now,
    String? approvedByUserId,
    String? saleDiscountReason,
  }) {
    return {
      'id': saleId,
      'inventoryTransactionId': inventoryTransactionId,
      'deviceId': deviceId,
      'completedAt': now.toIso8601String(),
      'subtotalMinor': pricing.subtotalMinor,
      'discountMinor': pricing.discountMinor,
      'taxMinor': pricing.taxMinor,
      'totalMinor': pricing.totalMinor,
      'tenderedMinor': reconciliation.tenderedMinor,
      'changeMinor': reconciliation.changeMinor,
      'discountApprovedByUserId': approvedByUserId,
      'saleDiscountReason': saleDiscountReason,
      'items': [
        for (final priced in pricing.lines)
          {
            'productId': priced.line.product.id,
            'stockLocationId': priced.line.product.stockLocationId,
            'quantityMilli': priced.line.quantityMilli,
            'unitPriceMinor': priced.line.product.unitPriceMinor,
            'unitCostMinor': priced.line.product.unitCostMinor,
            'taxRateBasisPoints': priced.line.product.taxRateBasisPoints,
            'taxInclusive': priced.line.product.taxInclusive,
            'productName': priced.line.product.name,
            'sku': priced.line.product.sku,
            'barcode': priced.line.product.primaryBarcode,
            'unitName': priced.line.product.unitName,
            'grossAmountMinor': priced.grossAmountMinor,
            'discountAmountMinor': priced.discountAmountMinor,
            'itemDiscountMinor': priced.itemDiscountMinor,
            'allocatedSaleDiscountMinor': priced.allocatedSaleDiscountMinor,
            'itemDiscountReason': priced.line.discountReason,
            'netAmountMinor': priced.netAmountMinor,
            'taxAmountMinor': priced.taxAmountMinor,
            'totalAmountMinor': priced.totalAmountMinor,
          },
      ],
      'payments': [
        for (final payment in reconciliation.payments)
          {
            'method': payment.method.databaseValue,
            'tenderedAmountMinor': payment.tenderedAmountMinor,
            'appliedAmountMinor': payment.appliedAmountMinor,
            'changeAmountMinor': payment.changeAmountMinor,
            'reference': payment.reference,
          },
      ],
    };
  }
}

Future<db.Branche?> _findBranch(AppDatabase database, BusinessContext context) {
  return (database.select(database.branches)..where(
        (row) =>
            row.id.equals(context.branchId) &
            row.organizationId.equals(context.organizationId) &
            row.deletedAt.isNull(),
      ))
      .getSingleOrNull();
}

class _CheckoutScope {
  const _CheckoutScope({
    required this.branch,
    required this.register,
    required this.shift,
  });

  final db.Branche branch;
  final db.Register register;
  final db.Shift? shift;
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
