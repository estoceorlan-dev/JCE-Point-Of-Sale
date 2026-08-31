import 'dart:convert';

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
import '../../domain/entities/stock_transfer.dart';
import '../../domain/repositories/transfers_repository.dart';
import '../data_sources/transfers_local_data_source.dart';

class DriftTransfersRepository implements TransfersRepository {
  const DriftTransfersRepository({
    required db.AppDatabase database,
    required TransfersLocalDataSource localDataSource,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _database = database,
       _localDataSource = localDataSource,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock;

  final db.AppDatabase _database;
  final TransfersLocalDataSource _localDataSource;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  InventoryLedgerWriter get _ledgerWriter =>
      InventoryLedgerWriter(idGenerator: _idGenerator);

  @override
  Stream<List<StockTransfer>> watchTransfers({
    required BusinessContext context,
  }) => _localDataSource.watchTransfers(
    organizationId: context.organizationId,
    branchId: context.branchId,
  );

  @override
  Future<StockTransfer?> getTransfer({
    required BusinessContext context,
    required String transferId,
  }) => _localDataSource.getTransfer(
    organizationId: context.organizationId,
    branchId: context.branchId,
    transferId: transferId,
  );

  @override
  Future<TransferOptions> getOptions({required BusinessContext context}) async {
    final branches =
        await (_database.select(_database.branches)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.name)]))
            .get();
    final locations =
        await (_database.select(_database.stockLocations)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.name)]))
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
    return TransferOptions(
      branches: branches
          .map(
            (row) => TransferBranchOption(
              id: row.id,
              code: row.code,
              name: row.name,
            ),
          )
          .toList(growable: false),
      locations: locations
          .map(
            (row) => TransferLocationOption(
              id: row.id,
              branchId: row.branchId,
              name: row.name,
              locationType: row.locationType,
              isDefault: row.isDefault,
            ),
          )
          .toList(growable: false),
      products: products
          .map(
            (row) =>
                TransferProductOption(id: row.id, sku: row.sku, name: row.name),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<TransferPolicy?> getPolicy({required BusinessContext context}) async {
    final branch = await _branch(
      _database,
      context.organizationId,
      context.branchId,
    );
    return branch == null
        ? null
        : TransferPolicy(
            approvalThresholdMilli: branch.transferApprovalThresholdMilli,
          );
  }

  @override
  Future<Result<void, Failure>> configurePolicy({
    required BusinessContext context,
    required TransferPolicy policy,
  }) {
    final threshold = policy.approvalThresholdMilli;
    if (threshold != null && threshold < 0) {
      return Future.value(
        const Result.failure(
          ValidationFailure('Transfer approval threshold cannot be negative.'),
        ),
      );
    }
    final now = _clock.nowUtc();
    final operationId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final changed =
            await (database.update(database.branches)..where(
                  (row) =>
                      row.id.equals(context.branchId) &
                      row.organizationId.equals(context.organizationId) &
                      row.deletedAt.isNull(),
                ))
                .write(
                  db.BranchesCompanion(
                    transferApprovalThresholdMilli: Value(threshold),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) {
          throw const AuthorizationFailure(
            'The active branch is unavailable locally.',
          );
        }
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.update,
        'transfer_policy',
        context.branchId,
        now,
        {'approvalThresholdMilli': threshold},
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'branch.transfer_policy.configure',
        'branch',
        context.branchId,
        now,
        {'approvalThresholdMilli': threshold},
      ),
    );
  }

  @override
  Future<Result<String, Failure>> createDraft({
    required BusinessContext context,
    required StockTransferDraft draft,
  }) async {
    final operationId = draft.operationId ?? _idGenerator.newId();
    final existing = await _eventForOperation(operationId);
    if (existing != null) {
      return existing.eventType == 'created'
          ? Result.success(existing.transferId)
          : const Result.failure(
              ConflictFailure('The operation ID belongs to another action.'),
            );
    }
    if (draft.destinationBranchId == context.branchId) {
      return const Result.failure(
        ValidationFailure('Source and destination branches must differ.'),
      );
    }
    if (draft.lines.isEmpty) {
      return const Result.failure(
        ValidationFailure('A transfer requires at least one item.'),
      );
    }
    final seen = <String>{};
    var totalQuantity = 0;
    for (final line in draft.lines) {
      if (line.quantityMilli <= 0 ||
          !seen.add('${line.sourceStockLocationId}:${line.productId}')) {
        return const Result.failure(
          ValidationFailure(
            'Transfer quantities must be positive and item/location lines unique.',
          ),
        );
      }
      totalQuantity += line.quantityMilli;
    }
    final transferId = _idGenerator.newId();
    final itemIds = [for (final _ in draft.lines) _idGenerator.newId()];
    final now = _clock.nowUtc();
    final sourceBranch = await _branch(
      _database,
      context.organizationId,
      context.branchId,
    );
    if (sourceBranch == null) {
      return const Result.failure(
        AuthorizationFailure('The source branch is unavailable locally.'),
      );
    }
    final transferNumber = _transferNumber(sourceBranch.code, now, transferId);
    final threshold = sourceBranch.transferApprovalThresholdMilli;
    final approvalRequired = threshold != null && totalQuantity > threshold;
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final destination = await _branch(
          database,
          context.organizationId,
          draft.destinationBranchId,
        );
        if (destination == null) {
          throw const AuthorizationFailure(
            'The destination branch is unavailable locally.',
          );
        }
        for (final line in draft.lines) {
          await _validateDraftLine(database, context, draft, line);
        }
        await database
            .into(database.stockTransfers)
            .insert(
              db.StockTransfersCompanion.insert(
                id: transferId,
                organizationId: context.organizationId,
                sourceBranchId: context.branchId,
                destinationBranchId: draft.destinationBranchId,
                transferNumber: transferNumber,
                status: StockTransferStatus.draft.databaseValue,
                approvalRequired: Value(approvalRequired),
                notes: Value(_trimmed(draft.notes)),
                createdByUserId: context.actorUserId,
                createdAt: now,
                updatedAt: now,
              ),
            );
        for (var index = 0; index < draft.lines.length; index++) {
          final line = draft.lines[index];
          await database
              .into(database.stockTransferItems)
              .insert(
                db.StockTransferItemsCompanion.insert(
                  id: itemIds[index],
                  organizationId: context.organizationId,
                  transferId: transferId,
                  productId: line.productId,
                  sourceStockLocationId: line.sourceStockLocationId,
                  destinationStockLocationId: line.destinationStockLocationId,
                  requestedQuantityMilli: line.quantityMilli,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
        await _insertEvent(
          database,
          context,
          transferId,
          operationId,
          'created',
          null,
          StockTransferStatus.draft,
          now,
        );
        return transferId;
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.transfer,
        'stock_transfer',
        transferId,
        now,
        {'event': 'created', 'destinationBranchId': draft.destinationBranchId},
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'transfer.create',
        'stock_transfer',
        transferId,
        now,
        {
          'id': transferId,
          'transferNumber': transferNumber,
          'sourceBranchId': context.branchId,
          'destinationBranchId': draft.destinationBranchId,
          'approvalRequired': approvalRequired,
          'notes': _trimmed(draft.notes),
          'createdAt': now.toIso8601String(),
          'lines': [
            for (var index = 0; index < draft.lines.length; index++)
              {
                'id': itemIds[index],
                'productId': draft.lines[index].productId,
                'sourceStockLocationId':
                    draft.lines[index].sourceStockLocationId,
                'destinationStockLocationId':
                    draft.lines[index].destinationStockLocationId,
                'quantityMilli': draft.lines[index].quantityMilli,
              },
          ],
        },
      ),
    );
  }

  @override
  Future<Result<void, Failure>> submit({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    String? operationId,
  }) => _submit(
    context,
    transferId,
    expectedVersion,
    operationId ?? _idGenerator.newId(),
  );

  Future<Result<void, Failure>> _submit(
    BusinessContext context,
    String transferId,
    int expectedVersion,
    String operationId,
  ) async {
    final duplicate = await _duplicateTransition(operationId, transferId);
    if (duplicate != null) return duplicate;
    final now = _clock.nowUtc();
    final dependency = await _latestOutboxOperation(transferId);
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final transfer = await _requireTransfer(
          database,
          context,
          transferId,
          sourceOnly: true,
        );
        _requireStateAndVersion(
          transfer,
          StockTransferStatus.draft,
          expectedVersion,
        );
        final next = transfer.approvalRequired
            ? StockTransferStatus.submitted
            : StockTransferStatus.approved;
        if (next == StockTransferStatus.approved) {
          await _reserve(database, transfer, reserve: true, now: now);
        }
        await _updateStatus(
          database,
          transfer,
          next,
          now,
          submittedAt: now,
          approvedAt: next == StockTransferStatus.approved ? now : null,
          approvedByUserId: next == StockTransferStatus.approved
              ? context.actorUserId
              : null,
        );
        await _insertEvent(
          database,
          context,
          transferId,
          operationId,
          next == StockTransferStatus.approved ? 'auto_approved' : 'submitted',
          StockTransferStatus.draft,
          next,
          now,
        );
      },
      auditEntry: _transitionAudit(
        context,
        operationId,
        transferId,
        'submit',
        now,
      ),
      outboxCommand: _transitionOutbox(
        context,
        operationId,
        transferId,
        'transfer.submit',
        expectedVersion,
        now,
        dependsOnOperationId: dependency,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> approve({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    String? operationId,
  }) => _approve(
    context,
    transferId,
    expectedVersion,
    operationId ?? _idGenerator.newId(),
  );

  Future<Result<void, Failure>> _approve(
    BusinessContext context,
    String transferId,
    int expectedVersion,
    String operationId,
  ) async {
    final duplicate = await _duplicateTransition(operationId, transferId);
    if (duplicate != null) return duplicate;
    final now = _clock.nowUtc();
    final dependency = await _latestOutboxOperation(transferId);
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final transfer = await _requireTransfer(
          database,
          context,
          transferId,
          sourceOnly: true,
        );
        _requireStateAndVersion(
          transfer,
          StockTransferStatus.submitted,
          expectedVersion,
        );
        await _reserve(database, transfer, reserve: true, now: now);
        await _updateStatus(
          database,
          transfer,
          StockTransferStatus.approved,
          now,
          approvedAt: now,
          approvedByUserId: context.actorUserId,
        );
        await _insertEvent(
          database,
          context,
          transferId,
          operationId,
          'approved',
          StockTransferStatus.submitted,
          StockTransferStatus.approved,
          now,
        );
      },
      auditEntry: _transitionAudit(
        context,
        operationId,
        transferId,
        'approve',
        now,
      ),
      outboxCommand: _transitionOutbox(
        context,
        operationId,
        transferId,
        'transfer.approve',
        expectedVersion,
        now,
        dependsOnOperationId: dependency,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> reject({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    required String reason,
    String? operationId,
  }) async {
    final normalizedReason = _trimmed(reason);
    if (normalizedReason == null) {
      return const Result.failure(
        ValidationFailure('A rejection reason is required.'),
      );
    }
    final op = operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateTransition(op, transferId);
    if (duplicate != null) return duplicate;
    final now = _clock.nowUtc();
    final dependency = await _latestOutboxOperation(transferId);
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final transfer = await _requireTransfer(
          database,
          context,
          transferId,
          sourceOnly: true,
        );
        _requireStateAndVersion(
          transfer,
          StockTransferStatus.submitted,
          expectedVersion,
        );
        await _updateStatus(
          database,
          transfer,
          StockTransferStatus.rejected,
          now,
          rejectionReason: normalizedReason,
        );
        await _insertEvent(
          database,
          context,
          transferId,
          op,
          'rejected',
          StockTransferStatus.submitted,
          StockTransferStatus.rejected,
          now,
          reason: normalizedReason,
        );
      },
      auditEntry: _transitionAudit(
        context,
        op,
        transferId,
        'reject',
        now,
        reason: normalizedReason,
      ),
      outboxCommand: _transitionOutbox(
        context,
        op,
        transferId,
        'transfer.reject',
        expectedVersion,
        now,
        dependsOnOperationId: dependency,
        reason: normalizedReason,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> ship({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    String? operationId,
  }) async {
    final op = operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateTransition(op, transferId);
    if (duplicate != null) return duplicate;
    final now = _clock.nowUtc();
    final dependency = await _latestOutboxOperation(transferId);
    final inventoryTransactionId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final transfer = await _requireTransfer(
          database,
          context,
          transferId,
          sourceOnly: true,
        );
        _requireStateAndVersion(
          transfer,
          StockTransferStatus.approved,
          expectedVersion,
        );
        final items = await _items(database, transferId);
        await _reserve(database, transfer, reserve: false, now: now);
        await _ledgerWriter.post(
          database: database,
          context: context,
          draft: InventoryMovementDraft(
            type: InventoryTransactionType.transferShipment,
            referenceType: 'stock_transfer',
            referenceId: transferId,
            lines: items
                .map(
                  (item) => InventoryMovementLineDraft(
                    stockLocationId: item.sourceStockLocationId,
                    productId: item.productId,
                    quantityDeltaMilli: -item.requestedQuantityMilli,
                  ),
                )
                .toList(growable: false),
          ),
          transactionId: inventoryTransactionId,
          operationId: '$op:inventory',
          now: now,
        );
        for (final item in items) {
          await (database.update(
            database.stockTransferItems,
          )..where((row) => row.id.equals(item.id))).write(
            db.StockTransferItemsCompanion(
              shippedQuantityMilli: Value(item.requestedQuantityMilli),
              discrepancyQuantityMilli: Value(item.requestedQuantityMilli),
              version: Value(item.version + 1),
              updatedAt: Value(now),
            ),
          );
        }
        await _updateStatus(
          database,
          transfer,
          StockTransferStatus.shipped,
          now,
          shippedAt: now,
        );
        await _insertEvent(
          database,
          context,
          transferId,
          op,
          'shipped',
          StockTransferStatus.approved,
          StockTransferStatus.shipped,
          now,
          metadata: {'inventoryTransactionId': inventoryTransactionId},
        );
      },
      auditEntry: _transitionAudit(context, op, transferId, 'ship', now),
      outboxCommand: _transitionOutbox(
        context,
        op,
        transferId,
        'transfer.ship',
        expectedVersion,
        now,
        dependsOnOperationId: dependency,
        extra: {'inventoryTransactionId': inventoryTransactionId},
      ),
    );
  }

  @override
  Future<Result<void, Failure>> receive({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    required TransferReceiptDraft draft,
  }) async {
    final op = draft.operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateTransition(op, transferId);
    if (duplicate != null) return duplicate;
    final now = _clock.nowUtc();
    final dependency = await _latestOutboxOperation(transferId);
    final inventoryTransactionId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final transfer = await _requireTransfer(
          database,
          context,
          transferId,
          destinationOnly: true,
        );
        _requireStateAndVersion(
          transfer,
          StockTransferStatus.shipped,
          expectedVersion,
        );
        final items = await _items(database, transferId);
        final receiptByItem = _validateReceipt(items, draft.lines);
        final ledgerLines = <String, InventoryMovementLineDraft>{};
        for (final item in items) {
          final receipt = receiptByItem[item.id]!;
          await _validateReceiptLocations(database, context, item, receipt);
          _addLedgerLine(
            ledgerLines,
            item.destinationStockLocationId,
            item.productId,
            receipt.receivedQuantityMilli,
          );
          if (receipt.damagedQuantityMilli > 0) {
            _addLedgerLine(
              ledgerLines,
              receipt.damagedStockLocationId!,
              item.productId,
              receipt.damagedQuantityMilli,
            );
          }
          final discrepancy =
              item.shippedQuantityMilli -
              receipt.receivedQuantityMilli -
              receipt.damagedQuantityMilli;
          await (database.update(
            database.stockTransferItems,
          )..where((row) => row.id.equals(item.id))).write(
            db.StockTransferItemsCompanion(
              receivedQuantityMilli: Value(receipt.receivedQuantityMilli),
              damagedQuantityMilli: Value(receipt.damagedQuantityMilli),
              damagedStockLocationId: Value(receipt.damagedStockLocationId),
              discrepancyQuantityMilli: Value(discrepancy),
              version: Value(item.version + 1),
              updatedAt: Value(now),
            ),
          );
        }
        String? transactionId;
        if (ledgerLines.isNotEmpty) {
          transactionId = inventoryTransactionId;
          await _ledgerWriter.post(
            database: database,
            context: context,
            draft: InventoryMovementDraft(
              type: InventoryTransactionType.transferReceipt,
              referenceType: 'stock_transfer',
              referenceId: transferId,
              notes: draft.notes,
              lines: ledgerLines.values.toList(growable: false),
            ),
            transactionId: transactionId,
            operationId: '$op:inventory',
            now: now,
          );
        }
        await _updateStatus(
          database,
          transfer,
          StockTransferStatus.received,
          now,
          receivedAt: now,
        );
        await _insertEvent(
          database,
          context,
          transferId,
          op,
          'received',
          StockTransferStatus.shipped,
          StockTransferStatus.received,
          now,
          metadata: {
            'inventoryTransactionId': transactionId,
            'lines': _receiptPayload(draft.lines),
          },
        );
      },
      auditEntry: _transitionAudit(context, op, transferId, 'receive', now),
      outboxCommand: _transitionOutbox(
        context,
        op,
        transferId,
        'transfer.receive',
        expectedVersion,
        now,
        dependsOnOperationId: dependency,
        extra: {
          'notes': _trimmed(draft.notes),
          'inventoryTransactionId': inventoryTransactionId,
          'lines': _receiptPayload(draft.lines),
        },
      ),
    );
  }

  @override
  Future<Result<void, Failure>> correctReceipt({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    required TransferCorrectionDraft draft,
    required String approvedByUserId,
  }) async {
    final reason = _trimmed(draft.reason);
    if (reason == null || approvedByUserId.trim().isEmpty) {
      return const Result.failure(
        ValidationFailure(
          'A correction reason and manager approval are required.',
        ),
      );
    }
    final op = draft.operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateTransition(op, transferId);
    if (duplicate != null) return duplicate;
    final now = _clock.nowUtc();
    final dependency = await _latestOutboxOperation(transferId);
    final inventoryTransactionId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final transfer = await _requireTransfer(
          database,
          context,
          transferId,
          destinationOnly: true,
        );
        _requireStateAndVersion(
          transfer,
          StockTransferStatus.received,
          expectedVersion,
        );
        final items = await _items(database, transferId);
        final correctionByItem = _validateCorrection(items, draft.lines);
        final ledgerLines = <String, InventoryMovementLineDraft>{};
        for (final item in items) {
          final correction = correctionByItem[item.id]!;
          await _validateCorrectionLocations(
            database,
            context,
            item,
            correction,
          );
          _addLedgerLine(
            ledgerLines,
            item.destinationStockLocationId,
            item.productId,
            correction.receivedQuantityMilli - item.receivedQuantityMilli,
          );
          if (item.damagedQuantityMilli > 0) {
            _addLedgerLine(
              ledgerLines,
              item.damagedStockLocationId!,
              item.productId,
              -item.damagedQuantityMilli,
            );
          }
          if (correction.damagedQuantityMilli > 0) {
            _addLedgerLine(
              ledgerLines,
              correction.damagedStockLocationId!,
              item.productId,
              correction.damagedQuantityMilli,
            );
          }
          final discrepancy =
              item.shippedQuantityMilli -
              correction.receivedQuantityMilli -
              correction.damagedQuantityMilli;
          await (database.update(
            database.stockTransferItems,
          )..where((row) => row.id.equals(item.id))).write(
            db.StockTransferItemsCompanion(
              receivedQuantityMilli: Value(correction.receivedQuantityMilli),
              damagedQuantityMilli: Value(correction.damagedQuantityMilli),
              damagedStockLocationId: Value(correction.damagedStockLocationId),
              discrepancyQuantityMilli: Value(discrepancy),
              version: Value(item.version + 1),
              updatedAt: Value(now),
            ),
          );
        }
        if (ledgerLines.isEmpty) {
          throw const ValidationFailure(
            'The correction does not change any quantity.',
          );
        }
        await _ledgerWriter.post(
          database: database,
          context: context,
          draft: InventoryMovementDraft(
            type: InventoryTransactionType.reversal,
            reasonCode: 'TRANSFER_CORRECTION',
            notes: _trimmed(draft.notes) == null
                ? draft.reason
                : '${draft.reason}: ${_trimmed(draft.notes)}',
            referenceType: 'stock_transfer_correction',
            referenceId: transferId,
            approvedByUserId: approvedByUserId,
            lines: ledgerLines.values.toList(growable: false),
          ),
          transactionId: inventoryTransactionId,
          operationId: '$op:inventory',
          now: now,
        );
        final updated =
            await (database.update(database.stockTransfers)..where(
                  (row) =>
                      row.id.equals(transferId) &
                      row.version.equals(expectedVersion),
                ))
                .write(
                  db.StockTransfersCompanion(
                    version: Value(expectedVersion + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) throw _versionConflict;
        await _insertEvent(
          database,
          context,
          transferId,
          op,
          'receipt_corrected',
          StockTransferStatus.received,
          StockTransferStatus.received,
          now,
          reason: reason,
          metadata: {
            'approvedByUserId': approvedByUserId,
            'inventoryTransactionId': inventoryTransactionId,
          },
        );
      },
      auditEntry: _transitionAudit(
        context,
        op,
        transferId,
        'correct_receipt',
        now,
        reason: reason,
      ),
      outboxCommand: _transitionOutbox(
        context,
        op,
        transferId,
        'transfer.correct_receipt',
        expectedVersion,
        now,
        dependsOnOperationId: dependency,
        reason: reason,
        extra: {
          'approvedByUserId': approvedByUserId,
          'notes': _trimmed(draft.notes),
          'inventoryTransactionId': inventoryTransactionId,
          'lines': draft.lines
              .map(
                (line) => {
                  'transferItemId': line.transferItemId,
                  'receivedQuantityMilli': line.receivedQuantityMilli,
                  'damagedQuantityMilli': line.damagedQuantityMilli,
                  'damagedStockLocationId': line.damagedStockLocationId,
                },
              )
              .toList(growable: false),
        },
      ),
    );
  }

  @override
  Future<Result<void, Failure>> cancel({
    required BusinessContext context,
    required String transferId,
    required int expectedVersion,
    required String reason,
    String? operationId,
  }) async {
    final normalizedReason = _trimmed(reason);
    if (normalizedReason == null) {
      return const Result.failure(
        ValidationFailure('A cancellation reason is required.'),
      );
    }
    final op = operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateTransition(op, transferId);
    if (duplicate != null) return duplicate;
    final now = _clock.nowUtc();
    final dependency = await _latestOutboxOperation(transferId);
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final transfer = await _requireTransfer(
          database,
          context,
          transferId,
          sourceOnly: true,
        );
        final status = StockTransferStatus.fromDatabase(transfer.status);
        if (!const {
              StockTransferStatus.draft,
              StockTransferStatus.submitted,
              StockTransferStatus.approved,
            }.contains(status) ||
            transfer.version != expectedVersion) {
          throw const ConflictFailure(
            'Only an unchanged draft, submitted, or approved transfer can be cancelled.',
          );
        }
        if (status == StockTransferStatus.approved) {
          await _reserve(database, transfer, reserve: false, now: now);
        }
        await _updateStatus(
          database,
          transfer,
          StockTransferStatus.cancelled,
          now,
          cancelledAt: now,
          cancellationReason: normalizedReason,
        );
        await _insertEvent(
          database,
          context,
          transferId,
          op,
          'cancelled',
          status,
          StockTransferStatus.cancelled,
          now,
          reason: normalizedReason,
        );
      },
      auditEntry: _transitionAudit(
        context,
        op,
        transferId,
        'cancel',
        now,
        reason: normalizedReason,
      ),
      outboxCommand: _transitionOutbox(
        context,
        op,
        transferId,
        'transfer.cancel',
        expectedVersion,
        now,
        dependsOnOperationId: dependency,
        reason: normalizedReason,
      ),
    );
  }

  Future<void> _validateDraftLine(
    db.AppDatabase database,
    BusinessContext context,
    StockTransferDraft draft,
    StockTransferLineDraft line,
  ) async {
    final source =
        await (database.select(database.stockLocations)..where(
              (row) =>
                  row.id.equals(line.sourceStockLocationId) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    final destination =
        await (database.select(database.stockLocations)..where(
              (row) =>
                  row.id.equals(line.destinationStockLocationId) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(draft.destinationBranchId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    final product =
        await (database.select(database.products)..where(
              (row) =>
                  row.id.equals(line.productId) &
                  row.organizationId.equals(context.organizationId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (source == null || destination == null || product == null) {
      throw const AuthorizationFailure(
        'A transfer item references an unavailable branch resource.',
      );
    }
  }

  Future<void> _reserve(
    db.AppDatabase database,
    db.StockTransfer transfer, {
    required bool reserve,
    required DateTime now,
  }) async {
    final branch = await _branch(
      database,
      transfer.organizationId,
      transfer.sourceBranchId,
    );
    if (branch == null) {
      throw const AuthorizationFailure('The source branch is unavailable.');
    }
    for (final item in await _items(database, transfer.id)) {
      final balance =
          await (database.select(database.inventoryBalances)..where(
                (row) =>
                    row.organizationId.equals(transfer.organizationId) &
                    row.branchId.equals(transfer.sourceBranchId) &
                    row.stockLocationId.equals(item.sourceStockLocationId) &
                    row.productId.equals(item.productId),
              ))
              .getSingleOrNull();
      if (balance == null) {
        throw const ValidationFailure(
          'Source stock is unavailable for a transfer item.',
        );
      }
      final nextReserved = reserve
          ? balance.reservedMilli + item.requestedQuantityMilli
          : balance.reservedMilli - item.requestedQuantityMilli;
      if (nextReserved < 0 ||
          reserve &&
              !branch.allowNegativeStock &&
              balance.onHandMilli < nextReserved) {
        throw const ValidationFailure(
          'Available source stock is insufficient for this transfer.',
        );
      }
      final changed =
          await (database.update(database.inventoryBalances)..where(
                (row) =>
                    row.id.equals(balance.id) &
                    row.version.equals(balance.version),
              ))
              .write(
                db.InventoryBalancesCompanion(
                  reservedMilli: Value(nextReserved),
                  version: Value(balance.version + 1),
                  updatedAt: Value(now),
                ),
              );
      if (changed != 1) throw _versionConflict;
    }
  }

  Map<String, TransferReceiptLineDraft> _validateReceipt(
    List<db.StockTransferItem> items,
    List<TransferReceiptLineDraft> lines,
  ) {
    final byItem = {for (final line in lines) line.transferItemId: line};
    if (byItem.length != items.length || lines.length != items.length) {
      throw const ValidationFailure(
        'Every shipped item must be reconciled once.',
      );
    }
    for (final item in items) {
      final line = byItem[item.id];
      if (line == null ||
          line.receivedQuantityMilli < 0 ||
          line.damagedQuantityMilli < 0 ||
          line.receivedQuantityMilli + line.damagedQuantityMilli >
              item.shippedQuantityMilli ||
          (line.damagedQuantityMilli > 0 &&
              _trimmed(line.damagedStockLocationId) == null)) {
        throw const ValidationFailure(
          'Received and damaged quantities must reconcile within shipped quantity.',
        );
      }
    }
    return byItem;
  }

  Map<String, TransferCorrectionLineDraft> _validateCorrection(
    List<db.StockTransferItem> items,
    List<TransferCorrectionLineDraft> lines,
  ) {
    final byItem = {for (final line in lines) line.transferItemId: line};
    if (byItem.length != items.length || lines.length != items.length) {
      throw const ValidationFailure(
        'Every received item must be reconciled once.',
      );
    }
    for (final item in items) {
      final line = byItem[item.id];
      if (line == null ||
          line.receivedQuantityMilli < 0 ||
          line.damagedQuantityMilli < 0 ||
          line.receivedQuantityMilli + line.damagedQuantityMilli >
              item.shippedQuantityMilli ||
          (line.damagedQuantityMilli > 0 &&
              _trimmed(line.damagedStockLocationId) == null)) {
        throw const ValidationFailure('Corrected quantities are invalid.');
      }
    }
    return byItem;
  }

  Future<void> _validateReceiptLocations(
    db.AppDatabase database,
    BusinessContext context,
    db.StockTransferItem item,
    TransferReceiptLineDraft line,
  ) async {
    await _requireDestinationLocation(
      database,
      context,
      item.destinationStockLocationId,
      damaged: false,
    );
    if (line.damagedQuantityMilli > 0) {
      await _requireDestinationLocation(
        database,
        context,
        line.damagedStockLocationId!,
        damaged: true,
      );
    }
  }

  Future<void> _validateCorrectionLocations(
    db.AppDatabase database,
    BusinessContext context,
    db.StockTransferItem item,
    TransferCorrectionLineDraft line,
  ) async {
    await _requireDestinationLocation(
      database,
      context,
      item.destinationStockLocationId,
      damaged: false,
    );
    if (line.damagedQuantityMilli > 0) {
      await _requireDestinationLocation(
        database,
        context,
        line.damagedStockLocationId!,
        damaged: true,
      );
    }
  }

  Future<void> _requireDestinationLocation(
    db.AppDatabase database,
    BusinessContext context,
    String locationId, {
    required bool damaged,
  }) async {
    final location =
        await (database.select(database.stockLocations)..where(
              (row) =>
                  row.id.equals(locationId) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (location == null || damaged && location.locationType != 'damaged') {
      throw ValidationFailure(
        damaged
            ? 'Damaged stock requires an active damaged location.'
            : 'The destination location is unavailable.',
      );
    }
  }

  void _addLedgerLine(
    Map<String, InventoryMovementLineDraft> lines,
    String locationId,
    String productId,
    int quantity,
  ) {
    if (quantity == 0) return;
    final key = '$locationId:$productId';
    final existing = lines[key];
    final next = (existing?.quantityDeltaMilli ?? 0) + quantity;
    if (next == 0) {
      lines.remove(key);
    } else {
      lines[key] = InventoryMovementLineDraft(
        stockLocationId: locationId,
        productId: productId,
        quantityDeltaMilli: next,
      );
    }
  }

  Future<db.StockTransfer> _requireTransfer(
    db.AppDatabase database,
    BusinessContext context,
    String transferId, {
    bool sourceOnly = false,
    bool destinationOnly = false,
  }) async {
    final transfer =
        await (database.select(database.stockTransfers)..where(
              (row) =>
                  row.id.equals(transferId) &
                  row.organizationId.equals(context.organizationId),
            ))
            .getSingleOrNull();
    final allowed =
        transfer != null &&
        (!sourceOnly || transfer.sourceBranchId == context.branchId) &&
        (!destinationOnly ||
            transfer.destinationBranchId == context.branchId) &&
        (sourceOnly ||
            destinationOnly ||
            transfer.sourceBranchId == context.branchId ||
            transfer.destinationBranchId == context.branchId);
    if (!allowed) {
      throw const AuthorizationFailure(
        'The transfer is outside the active branch context.',
      );
    }
    return transfer;
  }

  void _requireStateAndVersion(
    db.StockTransfer transfer,
    StockTransferStatus expectedStatus,
    int expectedVersion,
  ) {
    if (transfer.status != expectedStatus.databaseValue) {
      throw ConflictFailure(
        'A ${expectedStatus.label.toLowerCase()} transfer is required for this action.',
      );
    }
    if (transfer.version != expectedVersion) throw _versionConflict;
  }

  Future<void> _updateStatus(
    db.AppDatabase database,
    db.StockTransfer transfer,
    StockTransferStatus status,
    DateTime now, {
    DateTime? submittedAt,
    DateTime? approvedAt,
    DateTime? shippedAt,
    DateTime? receivedAt,
    DateTime? cancelledAt,
    String? approvedByUserId,
    String? rejectionReason,
    String? cancellationReason,
  }) async {
    final changed =
        await (database.update(database.stockTransfers)..where(
              (row) =>
                  row.id.equals(transfer.id) &
                  row.version.equals(transfer.version),
            ))
            .write(
              db.StockTransfersCompanion(
                status: Value(status.databaseValue),
                submittedAt: submittedAt == null
                    ? const Value.absent()
                    : Value(submittedAt),
                approvedAt: approvedAt == null
                    ? const Value.absent()
                    : Value(approvedAt),
                shippedAt: shippedAt == null
                    ? const Value.absent()
                    : Value(shippedAt),
                receivedAt: receivedAt == null
                    ? const Value.absent()
                    : Value(receivedAt),
                cancelledAt: cancelledAt == null
                    ? const Value.absent()
                    : Value(cancelledAt),
                approvedByUserId: approvedByUserId == null
                    ? const Value.absent()
                    : Value(approvedByUserId),
                rejectionReason: rejectionReason == null
                    ? const Value.absent()
                    : Value(rejectionReason),
                cancellationReason: cancellationReason == null
                    ? const Value.absent()
                    : Value(cancellationReason),
                version: Value(transfer.version + 1),
                updatedAt: Value(now),
              ),
            );
    if (changed != 1) throw _versionConflict;
  }

  Future<void> _insertEvent(
    db.AppDatabase database,
    BusinessContext context,
    String transferId,
    String operationId,
    String eventType,
    StockTransferStatus? fromStatus,
    StockTransferStatus toStatus,
    DateTime now, {
    String? reason,
    Map<String, Object?> metadata = const {},
  }) => database
      .into(database.transferEvents)
      .insert(
        db.TransferEventsCompanion.insert(
          id: _idGenerator.newId(),
          organizationId: context.organizationId,
          transferId: transferId,
          operationId: operationId,
          eventType: eventType,
          fromStatus: Value(fromStatus?.databaseValue),
          toStatus: toStatus.databaseValue,
          actorUserId: context.actorUserId,
          reason: Value(reason),
          metadataJson: Value(jsonEncode(metadata)),
          occurredAt: now,
          createdAt: now,
        ),
      );

  Future<db.TransferEvent?> _eventForOperation(String operationId) =>
      (_database.select(
        _database.transferEvents,
      )..where((row) => row.operationId.equals(operationId))).getSingleOrNull();

  Future<Result<void, Failure>?> _duplicateTransition(
    String operationId,
    String transferId,
  ) async {
    final event = await _eventForOperation(operationId);
    if (event == null) return null;
    return event.transferId == transferId
        ? const Result.success(null)
        : const Result.failure(
            ConflictFailure('The operation ID belongs to another transfer.'),
          );
  }

  Future<List<db.StockTransferItem>> _items(
    db.AppDatabase database,
    String transferId,
  ) => (database.select(
    database.stockTransferItems,
  )..where((row) => row.transferId.equals(transferId))).get();

  Future<db.Branche?> _branch(
    db.AppDatabase database,
    String organizationId,
    String branchId,
  ) =>
      (database.select(database.branches)..where(
            (row) =>
                row.id.equals(branchId) &
                row.organizationId.equals(organizationId) &
                row.isActive.equals(true) &
                row.deletedAt.isNull(),
          ))
          .getSingleOrNull();

  AuditLogEntry _transitionAudit(
    BusinessContext context,
    String operationId,
    String transferId,
    String event,
    DateTime now, {
    String? reason,
  }) => _audit(
    context,
    operationId,
    AuditActionType.transfer,
    'stock_transfer',
    transferId,
    now,
    {'event': event, if (reason != null) 'reason': reason},
  );

  OutboxCommand _transitionOutbox(
    BusinessContext context,
    String operationId,
    String transferId,
    String commandType,
    int expectedVersion,
    DateTime now, {
    required String? dependsOnOperationId,
    String? reason,
    Map<String, Object?> extra = const {},
  }) => _outbox(
    context,
    operationId,
    commandType,
    'stock_transfer',
    transferId,
    now,
    {
      'id': transferId,
      'expectedVersion': expectedVersion,
      'occurredAt': now.toIso8601String(),
      if (reason != null) 'reason': reason,
      ...extra,
    },
    dependsOnOperationId: dependsOnOperationId,
  );

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
    payload: payload,
    dependsOnOperationId: dependsOnOperationId,
    createdAt: now,
  );

  Future<String?> _latestOutboxOperation(String transferId) async {
    final rows = await _database
        .customSelect(
          'SELECT operation_id FROM sync_outbox '
          'WHERE aggregate_type = ? AND aggregate_id = ? '
          'ORDER BY rowid DESC LIMIT 1',
          variables: [
            const Variable<String>('stock_transfer'),
            Variable<String>(transferId),
          ],
          readsFrom: {_database.syncOutboxEntries},
        )
        .get();
    return rows.firstOrNull?.read<String>('operation_id');
  }
}

const _versionConflict = ConflictFailure(
  'The transfer changed after it was opened. Refresh and retry.',
);

String? _trimmed(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _transferNumber(String branchCode, DateTime now, String id) {
  final date =
      '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  final suffix = id.replaceAll('-', '').toUpperCase();
  return 'TR-${branchCode.toUpperCase()}-$date-${suffix.substring(0, 8)}';
}

List<Map<String, Object?>> _receiptPayload(
  List<TransferReceiptLineDraft> lines,
) => lines
    .map(
      (line) => {
        'transferItemId': line.transferItemId,
        'receivedQuantityMilli': line.receivedQuantityMilli,
        'damagedQuantityMilli': line.damagedQuantityMilli,
        'damagedStockLocationId': line.damagedStockLocationId,
      },
    )
    .toList(growable: false);
