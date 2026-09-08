import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart'
    hide InventoryBalance, StockCount, StockLocation;
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/inventory_adjustment.dart';
import '../../domain/entities/inventory_balance.dart';
import '../../domain/entities/inventory_movement.dart';
import '../../domain/entities/inventory_transaction_type.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_location.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../data_sources/inventory_local_data_source.dart';
import '../services/inventory_ledger_writer.dart';
import 'drift_stock_count_store.dart';
import 'drift_stock_location_store.dart';

class DriftInventoryRepository implements InventoryRepository {
  const DriftInventoryRepository({
    required AppDatabase database,
    required InventoryLocalDataSource localDataSource,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _database = database,
       _localDataSource = localDataSource,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock;

  final AppDatabase _database;
  final InventoryLocalDataSource _localDataSource;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  InventoryLedgerWriter get _ledgerWriter =>
      InventoryLedgerWriter(idGenerator: _idGenerator);

  DriftStockCountStore get _stockCountStore => DriftStockCountStore(
    database: _database,
    localMutationTransaction: _localMutationTransaction,
    idGenerator: _idGenerator,
    clock: _clock,
  );

  @override
  Stream<List<StockLocation>> watchStockLocations({
    required BusinessContext context,
    bool includeArchived = false,
  }) {
    return _localDataSource.watchStockLocations(
      includeArchived: includeArchived,
      organizationId: context.organizationId,
      branchId: context.branchId,
    );
  }

  DriftStockLocationStore get _locations => DriftStockLocationStore(
    database: _database,
    mutation: _localMutationTransaction,
    ids: _idGenerator,
    clock: _clock,
  );

  @override
  Future<Result<String, Failure>> createStockLocation({
    required BusinessContext context,
    required StockLocationDraft draft,
  }) => _locations.save(context: context, draft: draft);

  @override
  Future<Result<void, Failure>> updateStockLocation({
    required BusinessContext context,
    required String locationId,
    required StockLocationDraft draft,
    required int expectedVersion,
  }) async => (await _locations.save(
    context: context,
    draft: draft,
    locationId: locationId,
    expectedVersion: expectedVersion,
  )).map((_) {});

  @override
  Future<Result<void, Failure>> setStockLocationArchived({
    required BusinessContext context,
    required String locationId,
    required bool archived,
    required int expectedVersion,
  }) => _locations.setArchived(
    context: context,
    locationId: locationId,
    archived: archived,
    expectedVersion: expectedVersion,
  );

  @override
  Stream<List<InventoryBalance>> watchBalances({
    required BusinessContext context,
    InventoryBalanceQuery query = const InventoryBalanceQuery(),
  }) {
    return _localDataSource.watchBalances(
      organizationId: context.organizationId,
      branchId: context.branchId,
      filter: query,
    );
  }

  @override
  Stream<List<InventoryMovement>> watchMovements({
    required BusinessContext context,
    InventoryMovementFilter filter = const InventoryMovementFilter(),
  }) {
    return _localDataSource.watchMovements(
      organizationId: context.organizationId,
      branchId: context.branchId,
      filter: filter,
    );
  }

  @override
  Future<Result<String, Failure>> postMovement({
    required BusinessContext context,
    required InventoryMovementDraft draft,
  }) async {
    final operationId = draft.operationId ?? _idGenerator.newId();
    final existing = await _transactionForOperation(context, operationId);
    if (existing != null) {
      if (existing.transactionType != draft.type.databaseValue) {
        return const Result.failure(
          ConflictFailure('The operation ID belongs to another movement.'),
        );
      }
      return Result.success(existing.id);
    }
    final transactionId = _idGenerator.newId();
    final now = _clock.nowUtc();
    final normalizedDraft = InventoryMovementDraft(
      type: draft.type,
      lines: draft.lines,
      operationId: operationId,
      reasonCode: draft.reasonCode,
      notes: draft.notes,
      referenceType: draft.referenceType,
      referenceId: draft.referenceId,
      reversesTransactionId: draft.reversesTransactionId,
      approvedByUserId: draft.approvedByUserId,
      occurredAt: draft.occurredAt,
    );
    return _localMutationTransaction.execute(
      businessWrite: (database) => _ledgerWriter.post(
        database: database,
        context: context,
        draft: normalizedDraft,
        transactionId: transactionId,
        operationId: operationId,
        now: now,
      ),
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'inventory_transaction',
        entityId: transactionId,
        metadata: {
          'transactionType': draft.type.databaseValue,
          'lineCount': draft.lines.length,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'inventory.transaction.post',
        aggregateType: 'inventory_transaction',
        aggregateId: transactionId,
        payload: _movementPayload(transactionId, normalizedDraft),
        now: now,
      ),
    );
  }

  @override
  Future<Result<String, Failure>> createAdjustment({
    required BusinessContext context,
    required InventoryAdjustmentDraft draft,
    String? approvedByUserId,
  }) {
    if (draft.quantityDeltaMilli == 0 || draft.reasonCode.trim().isEmpty) {
      return Future.value(
        const Result.failure(
          ValidationFailure(
            'An adjustment requires a non-zero quantity and a reason.',
          ),
        ),
      );
    }
    final type = draft.quantityDeltaMilli > 0
        ? InventoryTransactionType.adjustmentIncrease
        : InventoryTransactionType.adjustmentDecrease;
    return postMovement(
      context: context,
      draft: InventoryMovementDraft(
        operationId: draft.operationId,
        type: type,
        reasonCode: draft.reasonCode,
        notes: draft.notes,
        approvedByUserId: approvedByUserId,
        lines: [
          InventoryMovementLineDraft(
            stockLocationId: draft.stockLocationId,
            productId: draft.productId,
            quantityDeltaMilli: draft.quantityDeltaMilli,
            expectedBalanceVersion: draft.expectedBalanceVersion,
          ),
        ],
      ),
    );
  }

  @override
  Future<Result<String, Failure>> reverseMovement({
    required BusinessContext context,
    required String transactionId,
    required String reason,
    String? operationId,
  }) async {
    final reversalOperationId = operationId ?? _idGenerator.newId();
    final existingByOperation = await _transactionForOperation(
      context,
      reversalOperationId,
    );
    if (existingByOperation != null) {
      return Result.success(existingByOperation.id);
    }
    final original =
        await (_database.select(_database.inventoryTransactions)..where(
              (row) =>
                  row.id.equals(transactionId) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId),
            ))
            .getSingleOrNull();
    if (original == null) {
      return const Result.failure(
        AuthorizationFailure('The inventory movement is not in this branch.'),
      );
    }
    if (original.status != 'posted' ||
        original.transactionType ==
            InventoryTransactionType.reversal.databaseValue) {
      return const Result.failure(
        ConflictFailure('This inventory movement cannot be reversed again.'),
      );
    }
    final existingReversal =
        await (_database.select(_database.inventoryTransactions)..where(
              (row) =>
                  row.reversesTransactionId.equals(transactionId) &
                  row.status.equals('posted'),
            ))
            .getSingleOrNull();
    if (existingReversal != null) {
      return const Result.failure(
        ConflictFailure('This inventory movement already has a reversal.'),
      );
    }
    final entries = await (_database.select(
      _database.inventoryLedgerEntries,
    )..where((row) => row.transactionId.equals(transactionId))).get();
    if (entries.isEmpty) {
      return const Result.failure(
        ConflictFailure('The inventory movement has no ledger entries.'),
      );
    }
    final reversalId = _idGenerator.newId();
    final now = _clock.nowUtc();
    final draft = InventoryMovementDraft(
      operationId: reversalOperationId,
      type: InventoryTransactionType.reversal,
      reasonCode: 'REVERSAL',
      notes: reason,
      referenceType: 'inventory_transaction',
      referenceId: transactionId,
      reversesTransactionId: transactionId,
      lines: entries
          .map(
            (entry) => InventoryMovementLineDraft(
              stockLocationId: entry.stockLocationId,
              productId: entry.productId,
              quantityDeltaMilli: -entry.quantityDeltaMilli,
            ),
          )
          .toList(growable: false),
    );
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _ledgerWriter.post(
          database: database,
          context: context,
          draft: draft,
          transactionId: reversalId,
          operationId: reversalOperationId,
          now: now,
        );
        final updated =
            await (database.update(database.inventoryTransactions)..where(
                  (row) =>
                      row.id.equals(transactionId) &
                      row.status.equals('posted'),
                ))
                .write(
                  const InventoryTransactionsCompanion(
                    status: Value('reversed'),
                  ),
                );
        if (updated != 1) {
          throw const ConflictFailure(
            'The movement changed before it could be reversed.',
          );
        }
        return reversalId;
      },
      auditEntry: _audit(
        context: context,
        operationId: reversalOperationId,
        action: AuditActionType.update,
        entityName: 'inventory_transaction',
        entityId: transactionId,
        metadata: {'reversalTransactionId': reversalId, 'reason': reason},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: reversalOperationId,
        commandType: 'inventory.transaction.reverse',
        aggregateType: 'inventory_transaction',
        aggregateId: transactionId,
        payload: _movementPayload(reversalId, draft),
        now: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> setReorderPoint({
    required BusinessContext context,
    required String stockLocationId,
    required String productId,
    required int reorderPointMilli,
    required int expectedVersion,
  }) async {
    if (reorderPointMilli < 0) {
      return const Result.failure(
        ValidationFailure('Reorder point cannot be negative.'),
      );
    }
    final now = _clock.nowUtc();
    final operationId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _requireLocationAndProduct(
          database,
          context,
          stockLocationId,
          productId,
        );
        final existing =
            await (database.select(database.inventoryBalances)..where(
                  (row) =>
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.stockLocationId.equals(stockLocationId) &
                      row.productId.equals(productId),
                ))
                .getSingleOrNull();
        if (existing == null) {
          if (expectedVersion != 0) {
            throw const ConflictFailure(
              'Inventory changed after this form was opened.',
            );
          }
          await database
              .into(database.inventoryBalances)
              .insert(
                InventoryBalancesCompanion.insert(
                  id: _idGenerator.newId(),
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  stockLocationId: stockLocationId,
                  productId: productId,
                  reorderPointMilli: Value(reorderPointMilli),
                  version: const Value(1),
                  updatedAt: now,
                ),
              );
        } else {
          if (existing.version != expectedVersion) {
            throw const ConflictFailure(
              'Inventory changed after this form was opened.',
            );
          }
          final updated =
              await (database.update(database.inventoryBalances)..where(
                    (row) =>
                        row.id.equals(existing.id) &
                        row.version.equals(expectedVersion),
                  ))
                  .write(
                    InventoryBalancesCompanion(
                      reorderPointMilli: Value(reorderPointMilli),
                      version: Value(expectedVersion + 1),
                      updatedAt: Value(now),
                    ),
                  );
          if (updated != 1) {
            throw const ConflictFailure(
              'Inventory changed while the reorder point was saved.',
            );
          }
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'inventory_reorder_point',
        entityId: '$stockLocationId:$productId',
        metadata: {'reorderPointMilli': reorderPointMilli},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'inventory.reorder_point.set',
        aggregateType: 'inventory_balance',
        aggregateId: '$stockLocationId:$productId',
        payload: {
          'stockLocationId': stockLocationId,
          'productId': productId,
          'reorderPointMilli': reorderPointMilli,
          'expectedVersion': expectedVersion,
        },
        now: now,
      ),
    );
  }

  @override
  Future<InventoryPolicy?> getPolicy({required BusinessContext context}) {
    return _localDataSource.getPolicy(
      organizationId: context.organizationId,
      branchId: context.branchId,
    );
  }

  @override
  Future<Result<void, Failure>> configurePolicy({
    required BusinessContext context,
    required InventoryPolicy policy,
  }) async {
    final threshold = policy.adjustmentApprovalThresholdMilli;
    if (threshold != null && threshold < 0) {
      return const Result.failure(
        ValidationFailure('The approval threshold cannot be negative.'),
      );
    }
    final now = _clock.nowUtc();
    final operationId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final updated =
            await (database.update(database.branches)..where(
                  (row) =>
                      row.id.equals(context.branchId) &
                      row.organizationId.equals(context.organizationId) &
                      row.deletedAt.isNull(),
                ))
                .write(
                  BranchesCompanion(
                    allowNegativeStock: Value(policy.allowNegativeStock),
                    adjustmentApprovalThresholdMilli: Value(threshold),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const AuthorizationFailure(
            'The active branch is unavailable locally.',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'inventory_policy',
        entityId: context.branchId,
        metadata: {
          'allowNegativeStock': policy.allowNegativeStock,
          'adjustmentApprovalThresholdMilli': threshold,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'inventory.policy.configure',
        aggregateType: 'branch',
        aggregateId: context.branchId,
        payload: {
          'allowNegativeStock': policy.allowNegativeStock,
          'adjustmentApprovalThresholdMilli': threshold,
        },
        now: now,
      ),
    );
  }

  @override
  Stream<List<StockCount>> watchStockCounts({
    required BusinessContext context,
  }) {
    return _localDataSource.watchStockCounts(
      organizationId: context.organizationId,
      branchId: context.branchId,
    );
  }

  @override
  Future<Result<String, Failure>> startStockCount({
    required BusinessContext context,
    required StartStockCountDraft draft,
  }) {
    return _stockCountStore.start(context: context, draft: draft);
  }

  @override
  Future<Result<void, Failure>> recordCountedQuantity({
    required BusinessContext context,
    required String stockCountId,
    required String itemId,
    required int countedQuantityMilli,
    required int expectedVersion,
  }) {
    return _stockCountStore.record(
      context: context,
      stockCountId: stockCountId,
      itemId: itemId,
      countedQuantityMilli: countedQuantityMilli,
      expectedVersion: expectedVersion,
    );
  }

  @override
  Future<Result<String?, Failure>> completeStockCount({
    required BusinessContext context,
    required String stockCountId,
    required int expectedVersion,
    String? operationId,
  }) {
    return _stockCountStore.complete(
      context: context,
      stockCountId: stockCountId,
      expectedVersion: expectedVersion,
      operationId: operationId,
    );
  }

  @override
  Future<Result<void, Failure>> cancelStockCount({
    required BusinessContext context,
    required String stockCountId,
    required int expectedVersion,
  }) {
    return _stockCountStore.cancel(
      context: context,
      stockCountId: stockCountId,
      expectedVersion: expectedVersion,
    );
  }

  Future<InventoryTransaction?> _transactionForOperation(
    BusinessContext context,
    String operationId,
  ) {
    return (_database.select(_database.inventoryTransactions)..where(
          (row) =>
              row.organizationId.equals(context.organizationId) &
              row.branchId.equals(context.branchId) &
              row.operationId.equals(operationId),
        ))
        .getSingleOrNull();
  }

  Future<void> _requireLocationAndProduct(
    AppDatabase database,
    BusinessContext context,
    String stockLocationId,
    String productId,
  ) async {
    final location =
        await (database.select(database.stockLocations)..where(
              (row) =>
                  row.id.equals(stockLocationId) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    final product =
        await (database.select(database.products)..where(
              (row) =>
                  row.id.equals(productId) &
                  row.organizationId.equals(context.organizationId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (location == null || product == null) {
      throw const AuthorizationFailure(
        'The location or product is outside the active branch context.',
      );
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

  Map<String, Object?> _movementPayload(
    String transactionId,
    InventoryMovementDraft draft,
  ) {
    return {
      'id': transactionId,
      'transactionType': draft.type.databaseValue,
      'reasonCode': draft.reasonCode,
      'notes': draft.notes,
      'referenceType': draft.referenceType,
      'referenceId': draft.referenceId,
      'reversesTransactionId': draft.reversesTransactionId,
      'approvedByUserId': draft.approvedByUserId,
      'occurredAt': draft.occurredAt?.toUtc().toIso8601String(),
      'lines': draft.lines
          .map(
            (line) => {
              'stockLocationId': line.stockLocationId,
              'productId': line.productId,
              'quantityDeltaMilli': line.quantityDeltaMilli,
              'expectedBalanceVersion': line.expectedBalanceVersion,
            },
          )
          .toList(growable: false),
    };
  }
}
