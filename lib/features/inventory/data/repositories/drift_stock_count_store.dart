import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/inventory_movement.dart';
import '../../domain/entities/inventory_transaction_type.dart';
import '../../domain/entities/stock_count.dart';
import '../services/inventory_ledger_writer.dart';

class DriftStockCountStore {
  const DriftStockCountStore({
    required AppDatabase database,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _database = database,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock;

  final AppDatabase _database;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  InventoryLedgerWriter get _ledgerWriter =>
      InventoryLedgerWriter(idGenerator: _idGenerator);

  Future<Result<String, Failure>> start({
    required BusinessContext context,
    required StartStockCountDraft draft,
  }) async {
    final operationId = draft.operationId ?? _idGenerator.newId();
    final existing =
        await (_database.select(_database.stockCounts)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.operationId.equals(operationId),
            ))
            .getSingleOrNull();
    if (existing != null) return Result.success(existing.id);
    final countId = _idGenerator.newId();
    final now = _clock.nowUtc();
    final itemPayload = <Map<String, Object?>>[];
    final productIds = <String>[];
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final location =
            await (database.select(database.stockLocations)..where(
                  (row) =>
                      row.id.equals(draft.stockLocationId) &
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.isActive.equals(true) &
                      row.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (location == null) {
          throw const AuthorizationFailure(
            'The stock location is outside the active branch.',
          );
        }
        final active =
            await (database.select(database.stockCounts)..where(
                  (row) =>
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.stockLocationId.equals(draft.stockLocationId) &
                      row.status.equals('in_progress'),
                ))
                .getSingleOrNull();
        if (active != null) {
          throw const ConflictFailure(
            'This location already has a stock count in progress.',
          );
        }
        final productQuery = database.select(database.products)
          ..where(
            (row) =>
                row.organizationId.equals(context.organizationId) &
                row.isActive.equals(true) &
                row.deletedAt.isNull(),
          );
        final requestedIds = draft.productIds.toSet();
        if (draft.type == StockCountType.cycle) {
          if (requestedIds.isEmpty) {
            throw const ValidationFailure(
              'A cycle count requires at least one product.',
            );
          }
          productQuery.where((row) => row.id.isIn(requestedIds));
        }
        final products = await productQuery.get();
        if (products.isEmpty ||
            (draft.type == StockCountType.cycle &&
                products.length != requestedIds.length)) {
          throw const AuthorizationFailure(
            'One or more count products are unavailable in this organization.',
          );
        }
        await database
            .into(database.stockCounts)
            .insert(
              StockCountsCompanion.insert(
                id: countId,
                organizationId: context.organizationId,
                branchId: context.branchId,
                stockLocationId: draft.stockLocationId,
                operationId: operationId,
                countType: draft.type.databaseValue,
                notes: Value(_trimmedOrNull(draft.notes)),
                startedByUserId: context.actorUserId,
                startedAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        for (final product in products) {
          final itemId = _idGenerator.newId();
          itemPayload.add({'id': itemId, 'productId': product.id});
          productIds.add(product.id);
          final balance =
              await (database.select(database.inventoryBalances)..where(
                    (row) =>
                        row.organizationId.equals(context.organizationId) &
                        row.branchId.equals(context.branchId) &
                        row.stockLocationId.equals(draft.stockLocationId) &
                        row.productId.equals(product.id),
                  ))
                  .getSingleOrNull();
          await database
              .into(database.stockCountItems)
              .insert(
                StockCountItemsCompanion.insert(
                  id: itemId,
                  organizationId: context.organizationId,
                  stockCountId: countId,
                  productId: product.id,
                  expectedQuantityMilli: balance?.onHandMilli ?? 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
        return countId;
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.create,
        entityName: 'stock_count',
        entityId: countId,
        metadata: {
          'countType': draft.type.databaseValue,
          'stockLocationId': draft.stockLocationId,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'stock_count.start',
        aggregateId: countId,
        payload: {
          'id': countId,
          'stockLocationId': draft.stockLocationId,
          'countType': draft.type.databaseValue,
          'productIds': productIds,
          'items': itemPayload,
          'notes': draft.notes,
          'startedAt': now.toIso8601String(),
        },
        now: now,
      ),
    );
  }

  Future<Result<void, Failure>> record({
    required BusinessContext context,
    required String stockCountId,
    required String itemId,
    required int countedQuantityMilli,
    required int expectedVersion,
  }) async {
    if (countedQuantityMilli < 0) {
      return const Result.failure(
        ValidationFailure('Counted quantity cannot be negative.'),
      );
    }
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final count =
            await (database.select(database.stockCounts)..where(
                  (row) =>
                      row.id.equals(stockCountId) &
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.status.equals('in_progress'),
                ))
                .getSingleOrNull();
        if (count == null) {
          throw const ConflictFailure(
            'The stock count is no longer active in this branch.',
          );
        }
        final item =
            await (database.select(database.stockCountItems)..where(
                  (row) =>
                      row.id.equals(itemId) &
                      row.stockCountId.equals(stockCountId) &
                      row.organizationId.equals(context.organizationId),
                ))
                .getSingleOrNull();
        if (item == null) {
          throw const AuthorizationFailure(
            'The stock count item is outside the active count.',
          );
        }
        if (item.version != expectedVersion) {
          throw const ConflictFailure(
            'This count item was updated elsewhere. Refresh and retry.',
          );
        }
        final updated =
            await (database.update(database.stockCountItems)..where(
                  (row) =>
                      row.id.equals(itemId) &
                      row.version.equals(expectedVersion),
                ))
                .write(
                  StockCountItemsCompanion(
                    countedQuantityMilli: Value(countedQuantityMilli),
                    varianceQuantityMilli: Value(
                      countedQuantityMilli - item.expectedQuantityMilli,
                    ),
                    countedByUserId: Value(context.actorUserId),
                    countedAt: Value(now),
                    version: Value(expectedVersion + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const ConflictFailure(
            'This count item changed while it was being saved.',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'stock_count_item',
        entityId: itemId,
        metadata: {'countedQuantityMilli': countedQuantityMilli},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'stock_count.item.record',
        aggregateId: stockCountId,
        payload: {
          'stockCountId': stockCountId,
          'itemId': itemId,
          'countedQuantityMilli': countedQuantityMilli,
          'expectedVersion': expectedVersion,
        },
        now: now,
      ),
    );
  }

  Future<Result<String?, Failure>> complete({
    required BusinessContext context,
    required String stockCountId,
    required int expectedVersion,
    String? operationId,
  }) async {
    final completionOperationId = operationId ?? _idGenerator.newId();
    final initial =
        await (_database.select(_database.stockCounts)..where(
              (row) =>
                  row.id.equals(stockCountId) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId),
            ))
            .getSingleOrNull();
    if (initial == null) {
      return const Result.failure(
        AuthorizationFailure('The stock count is outside the active branch.'),
      );
    }
    if (initial.status == 'completed' &&
        initial.completionOperationId == completionOperationId) {
      final correction = await _transactionForOperation(
        context,
        completionOperationId,
      );
      return Result.success(correction?.id);
    }
    if (initial.status != 'in_progress') {
      return const Result.failure(
        ConflictFailure('The stock count is no longer in progress.'),
      );
    }
    final items = await (_database.select(
      _database.stockCountItems,
    )..where((row) => row.stockCountId.equals(stockCountId))).get();
    if (items.isEmpty ||
        items.any((item) => item.countedQuantityMilli == null)) {
      return const Result.failure(
        ValidationFailure('Every stock count item must be counted first.'),
      );
    }
    final corrections = items
        .where((item) => item.varianceQuantityMilli != 0)
        .map(
          (item) => InventoryMovementLineDraft(
            stockLocationId: initial.stockLocationId,
            productId: item.productId,
            quantityDeltaMilli: item.varianceQuantityMilli!,
          ),
        )
        .toList(growable: false);
    final correctionId = corrections.isEmpty ? null : _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        if (correctionId != null) {
          await _ledgerWriter.post(
            database: database,
            context: context,
            draft: InventoryMovementDraft(
              operationId: completionOperationId,
              type: InventoryTransactionType.stockCountCorrection,
              reasonCode: 'STOCK_COUNT_VARIANCE',
              referenceType: 'stock_count',
              referenceId: stockCountId,
              lines: corrections,
            ),
            transactionId: correctionId,
            operationId: completionOperationId,
            now: now,
          );
        }
        final updated =
            await (database.update(database.stockCounts)..where(
                  (row) =>
                      row.id.equals(stockCountId) &
                      row.status.equals('in_progress') &
                      row.version.equals(expectedVersion),
                ))
                .write(
                  StockCountsCompanion(
                    completionOperationId: Value(completionOperationId),
                    status: const Value('completed'),
                    completedByUserId: Value(context.actorUserId),
                    completedAt: Value(now),
                    version: Value(expectedVersion + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const ConflictFailure(
            'The stock count changed before completion. Refresh and retry.',
          );
        }
        return correctionId;
      },
      auditEntry: _audit(
        context: context,
        operationId: completionOperationId,
        action: AuditActionType.update,
        entityName: 'stock_count',
        entityId: stockCountId,
        metadata: {
          'status': 'completed',
          'correctionTransactionId': correctionId,
          'varianceLineCount': corrections.length,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: completionOperationId,
        commandType: 'stock_count.complete',
        aggregateId: stockCountId,
        payload: {
          'stockCountId': stockCountId,
          'expectedVersion': expectedVersion,
          'correctionTransactionId': correctionId,
          'corrections': corrections
              .map(
                (line) => {
                  'stockLocationId': line.stockLocationId,
                  'productId': line.productId,
                  'quantityDeltaMilli': line.quantityDeltaMilli,
                },
              )
              .toList(growable: false),
        },
        now: now,
      ),
    );
  }

  Future<Result<void, Failure>> cancel({
    required BusinessContext context,
    required String stockCountId,
    required int expectedVersion,
  }) {
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final updated =
            await (database.update(database.stockCounts)..where(
                  (row) =>
                      row.id.equals(stockCountId) &
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.status.equals('in_progress') &
                      row.version.equals(expectedVersion),
                ))
                .write(
                  StockCountsCompanion(
                    status: const Value('cancelled'),
                    version: Value(expectedVersion + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const ConflictFailure(
            'The stock count changed before it could be cancelled.',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.delete,
        entityName: 'stock_count',
        entityId: stockCountId,
        metadata: const {'status': 'cancelled'},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'stock_count.cancel',
        aggregateId: stockCountId,
        payload: {
          'stockCountId': stockCountId,
          'expectedVersion': expectedVersion,
        },
        now: now,
      ),
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
      aggregateType: 'stock_count',
      aggregateId: aggregateId,
      payload: payload,
      createdAt: now,
    );
  }
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
