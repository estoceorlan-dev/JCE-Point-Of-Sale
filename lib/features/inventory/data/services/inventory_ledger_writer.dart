import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/inventory_movement.dart';
import '../../domain/entities/inventory_transaction_type.dart';

class InventoryLedgerWriter {
  const InventoryLedgerWriter({required IdGenerator idGenerator})
    : _idGenerator = idGenerator;

  final IdGenerator _idGenerator;

  Future<String> post({
    required AppDatabase database,
    required BusinessContext context,
    required InventoryMovementDraft draft,
    required String transactionId,
    required String operationId,
    required DateTime now,
  }) async {
    _validateLines(draft);
    await _validateScope(database, context, draft);
    final policy = await _loadPolicy(database, context);
    _requireAdjustmentApproval(draft, policy.approvalThresholdMilli);

    await database
        .into(database.inventoryTransactions)
        .insert(
          InventoryTransactionsCompanion.insert(
            id: transactionId,
            organizationId: context.organizationId,
            branchId: context.branchId,
            operationId: operationId,
            transactionType: draft.type.databaseValue,
            reasonCode: Value(_trimmedOrNull(draft.reasonCode)),
            notes: Value(_trimmedOrNull(draft.notes)),
            referenceType: Value(_trimmedOrNull(draft.referenceType)),
            referenceId: Value(_trimmedOrNull(draft.referenceId)),
            reversesTransactionId: Value(draft.reversesTransactionId),
            createdByUserId: context.actorUserId,
            approvedByUserId: Value(draft.approvedByUserId),
            approvedAt: Value(draft.approvedByUserId == null ? null : now),
            occurredAt: (draft.occurredAt ?? now).toUtc(),
            createdAt: now,
          ),
        );

    for (final line in draft.lines) {
      final existing =
          await (database.select(database.inventoryBalances)..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(context.branchId) &
                    row.stockLocationId.equals(line.stockLocationId) &
                    row.productId.equals(line.productId),
              ))
              .getSingleOrNull();
      final currentVersion = existing?.version ?? 0;
      if (line.expectedBalanceVersion case final expected?) {
        if (expected != currentVersion) {
          throw const ConflictFailure(
            'Inventory changed after this form was opened. Refresh and retry.',
          );
        }
      }
      final currentOnHand = existing?.onHandMilli ?? 0;
      final nextOnHand = currentOnHand + line.quantityDeltaMilli;
      if (!policy.allowNegativeStock && nextOnHand < 0) {
        throw const ValidationFailure(
          'This movement would create negative stock for the branch.',
        );
      }

      if (existing == null) {
        await database
            .into(database.inventoryBalances)
            .insert(
              InventoryBalancesCompanion.insert(
                id: _idGenerator.newId(),
                organizationId: context.organizationId,
                branchId: context.branchId,
                stockLocationId: line.stockLocationId,
                productId: line.productId,
                onHandMilli: Value(nextOnHand),
                version: const Value(1),
                updatedAt: now,
              ),
            );
      } else {
        final changed =
            await (database.update(database.inventoryBalances)..where(
                  (row) =>
                      row.id.equals(existing.id) &
                      row.version.equals(currentVersion),
                ))
                .write(
                  InventoryBalancesCompanion(
                    onHandMilli: Value(nextOnHand),
                    version: Value(currentVersion + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) {
          throw const ConflictFailure(
            'Inventory changed during the operation. Refresh and retry.',
          );
        }
      }

      await database
          .into(database.inventoryLedgerEntries)
          .insert(
            InventoryLedgerEntriesCompanion.insert(
              id: _idGenerator.newId(),
              organizationId: context.organizationId,
              branchId: context.branchId,
              transactionId: transactionId,
              stockLocationId: line.stockLocationId,
              productId: line.productId,
              quantityDeltaMilli: line.quantityDeltaMilli,
              balanceAfterMilli: nextOnHand,
              occurredAt: (draft.occurredAt ?? now).toUtc(),
              createdAt: now,
            ),
          );
    }
    return transactionId;
  }

  void _validateLines(InventoryMovementDraft draft) {
    if (draft.lines.isEmpty) {
      throw const ValidationFailure(
        'An inventory movement requires at least one line.',
      );
    }
    final scopes = <String>{};
    for (final line in draft.lines) {
      if (line.stockLocationId.trim().isEmpty ||
          line.productId.trim().isEmpty ||
          line.quantityDeltaMilli == 0) {
        throw const ValidationFailure(
          'Inventory movement lines require a location, product, and non-zero quantity.',
        );
      }
      if (!scopes.add('${line.stockLocationId}:${line.productId}')) {
        throw const ValidationFailure(
          'Duplicate product and location lines must be combined.',
        );
      }
      if (!_directionIsValid(draft.type, line.quantityDeltaMilli)) {
        throw ValidationFailure(
          '${draft.type.label} has an invalid quantity direction.',
        );
      }
    }
  }

  Future<void> _validateScope(
    AppDatabase database,
    BusinessContext context,
    InventoryMovementDraft draft,
  ) async {
    for (final line in draft.lines) {
      final location =
          await (database.select(database.stockLocations)..where(
                (row) =>
                    row.id.equals(line.stockLocationId) &
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(context.branchId) &
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
      if (location == null || product == null) {
        throw const AuthorizationFailure(
          'The inventory location or product is outside the active branch context.',
          code: 'cross-scope-inventory-reference',
        );
      }
      if (draft.type != InventoryTransactionType.stockCountCorrection) {
        final activeCount =
            await (database.select(database.stockCounts)..where(
                  (row) =>
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.stockLocationId.equals(line.stockLocationId) &
                      row.status.equals('in_progress'),
                ))
                .getSingleOrNull();
        if (activeCount != null) {
          throw const ConflictFailure(
            'This stock location is frozen while its stock count is in progress.',
          );
        }
      }
    }
  }

  Future<_InventoryPolicyRow> _loadPolicy(
    AppDatabase database,
    BusinessContext context,
  ) async {
    final branch =
        await (database.select(database.branches)..where(
              (row) =>
                  row.id.equals(context.branchId) &
                  row.organizationId.equals(context.organizationId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (branch == null) {
      throw const AuthorizationFailure(
        'The active branch is not available locally.',
      );
    }
    return _InventoryPolicyRow(
      allowNegativeStock: branch.allowNegativeStock,
      approvalThresholdMilli: branch.adjustmentApprovalThresholdMilli,
    );
  }

  void _requireAdjustmentApproval(
    InventoryMovementDraft draft,
    int? threshold,
  ) {
    final isAdjustment =
        draft.type == InventoryTransactionType.adjustmentIncrease ||
        draft.type == InventoryTransactionType.adjustmentDecrease;
    if (!isAdjustment || threshold == null) return;
    final largestAdjustment = draft.lines.fold<int>(
      0,
      (largest, line) => math.max(largest, line.quantityDeltaMilli.abs()),
    );
    if (largestAdjustment > threshold && draft.approvedByUserId == null) {
      throw const AuthorizationFailure(
        'This adjustment exceeds the branch approval threshold.',
        code: 'inventory-approval-required',
      );
    }
  }
}

class _InventoryPolicyRow {
  const _InventoryPolicyRow({
    required this.allowNegativeStock,
    required this.approvalThresholdMilli,
  });

  final bool allowNegativeStock;
  final int? approvalThresholdMilli;
}

bool _directionIsValid(InventoryTransactionType type, int quantity) {
  return switch (type) {
    InventoryTransactionType.openingBalance ||
    InventoryTransactionType.purchaseReceipt ||
    InventoryTransactionType.saleReturn ||
    InventoryTransactionType.adjustmentIncrease ||
    InventoryTransactionType.transferReceipt => quantity > 0,
    InventoryTransactionType.sale ||
    InventoryTransactionType.adjustmentDecrease ||
    InventoryTransactionType.transferShipment => quantity < 0,
    InventoryTransactionType.stockCountCorrection ||
    InventoryTransactionType.reversal => quantity != 0,
  };
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
