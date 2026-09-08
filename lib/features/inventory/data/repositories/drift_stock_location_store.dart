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
import '../../domain/entities/stock_location.dart';

class DriftStockLocationStore {
  const DriftStockLocationStore({
    required this.database,
    required this.mutation,
    required this.ids,
    required this.clock,
  });
  final db.AppDatabase database;
  final LocalMutationTransaction mutation;
  final IdGenerator ids;
  final AppClock clock;

  Future<Result<String, Failure>> save({
    required BusinessContext context,
    required StockLocationDraft draft,
    String? locationId,
    int? expectedVersion,
  }) async {
    final code = draft.code.trim().toUpperCase().replaceAll(
      RegExp(r'\s+'),
      '_',
    );
    final name = draft.name.trim();
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{1,19}$').hasMatch(code) ||
        name.length < 2 ||
        name.length > 120) {
      return const Result.failure(
        ValidationFailure(
          'Use a 2–20 character location code and a 2–120 character name.',
        ),
      );
    }
    final id = locationId ?? ids.newId();
    final operation = ids.newId();
    final now = clock.nowUtc();
    final type = locationId == null
        ? 'stock_location.create'
        : 'stock_location.update';
    final payload = <String, Object?>{
      'id': id,
      'code': code,
      'name': name,
      'locationType': draft.type.databaseValue,
      'isDefault': draft.isDefault,
      if (locationId != null) 'expectedVersion': expectedVersion,
    };
    return mutation.execute(
      businessWrite: (_) async {
        await _requireBranch(context);
        // Default changes affect more than one record; finish earlier location
        // operations first so every affected version can converge safely.
        if (locationId != null || draft.isDefault) {
          await _requireNoPending(context, locationsOnly: true);
        }
        db.StockLocation? current;
        if (locationId != null) {
          current = await _requireLocation(context, id, expectedVersion);
          if (!current.isActive || current.deletedAt != null) {
            throw const ValidationFailure(
              'Restore the location before editing it.',
            );
          }
          if (current.isDefault && !draft.isDefault) {
            throw const ValidationFailure(
              'Choose another default location first.',
            );
          }
          if (current.locationType != draft.type.databaseValue) {
            await _requireNoWork(context, id);
          }
        }
        final duplicate = await database
            .customSelect(
              'SELECT id FROM stock_locations WHERE organization_id = ? AND branch_id = ? '
              'AND upper(trim(code)) = ? AND id <> ? LIMIT 1',
              variables: [
                Variable(context.organizationId),
                Variable(context.branchId),
                Variable(code),
                Variable(id),
              ],
              readsFrom: {database.stockLocations},
            )
            .getSingleOrNull();
        if (duplicate != null) {
          throw const ConflictFailure(
            'A stock location with this code already exists.',
          );
        }
        if (draft.isDefault) {
          await database.customUpdate(
            'UPDATE stock_locations SET is_default = 0, version = version + 1, updated_at = ? '
            'WHERE organization_id = ? AND branch_id = ? AND is_default = 1 AND id <> ?',
            variables: [
              Variable(now.toIso8601String()),
              Variable(context.organizationId),
              Variable(context.branchId),
              Variable(id),
            ],
            updates: {database.stockLocations},
          );
        }
        if (current == null) {
          await database
              .into(database.stockLocations)
              .insert(
                db.StockLocationsCompanion.insert(
                  id: id,
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  code: code,
                  name: name,
                  locationType: Value(draft.type.databaseValue),
                  isDefault: Value(draft.isDefault),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        } else {
          await (database.update(
            database.stockLocations,
          )..where((row) => row.id.equals(id))).write(
            db.StockLocationsCompanion(
              code: Value(code),
              name: Value(name),
              locationType: Value(draft.type.databaseValue),
              isDefault: Value(draft.isDefault),
              version: Value(current.version + 1),
              updatedAt: Value(now),
            ),
          );
        }
        return id;
      },
      auditEntry: _audit(
        context,
        operation,
        id,
        locationId == null ? AuditActionType.create : AuditActionType.update,
        payload,
        now,
      ),
      outboxCommand: _command(context, operation, id, type, payload, now),
    );
  }

  Future<Result<void, Failure>> setArchived({
    required BusinessContext context,
    required String locationId,
    required bool archived,
    required int expectedVersion,
  }) async {
    final operation = ids.newId();
    final now = clock.nowUtc();
    final payload = <String, Object?>{'expectedVersion': expectedVersion};
    return mutation.execute(
      businessWrite: (_) async {
        await _requireBranch(context);
        final current = await _requireLocation(
          context,
          locationId,
          expectedVersion,
        );
        await _requireNoPending(context, locationsOnly: !archived);
        if (archived) {
          if (!current.isActive || current.deletedAt != null) {
            throw const ValidationFailure('The location is already archived.');
          }
          if (current.isDefault) {
            throw const ValidationFailure(
              'Choose another default location before archiving.',
            );
          }
          final active =
              await (database.select(database.stockLocations)..where(
                    (row) =>
                        row.organizationId.equals(context.organizationId) &
                        row.branchId.equals(context.branchId) &
                        row.isActive.equals(true) &
                        row.deletedAt.isNull(),
                  ))
                  .get();
          if (active.length < 2) {
            throw const ValidationFailure(
              'Keep at least one active stock location.',
            );
          }
          final stock =
              await (database.select(database.inventoryBalances)
                    ..where(
                      (row) =>
                          row.organizationId.equals(context.organizationId) &
                          row.branchId.equals(context.branchId) &
                          row.stockLocationId.equals(locationId) &
                          (row.onHandMilli.equals(0).not() |
                              row.reservedMilli.equals(0).not()),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          if (stock != null) {
            throw const ValidationFailure(
              'Move or reconcile all stock and reservations before archiving.',
            );
          }
          await _requireNoWork(context, locationId);
        } else if (current.isActive && current.deletedAt == null) {
          throw const ValidationFailure('The location is already active.');
        }
        await (database.update(
          database.stockLocations,
        )..where((row) => row.id.equals(locationId))).write(
          db.StockLocationsCompanion(
            isActive: Value(!archived),
            deletedAt: Value(archived ? now : null),
            version: Value(current.version + 1),
            updatedAt: Value(now),
          ),
        );
      },
      auditEntry: _audit(
        context,
        operation,
        locationId,
        archived ? AuditActionType.delete : AuditActionType.update,
        {'archived': archived},
        now,
      ),
      outboxCommand: _command(
        context,
        operation,
        locationId,
        archived ? 'stock_location.archive' : 'stock_location.restore',
        payload,
        now,
      ),
    );
  }

  Future<void> _requireBranch(BusinessContext context) async {
    final branch =
        await (database.select(database.branches)..where(
              (row) =>
                  row.id.equals(context.branchId) &
                  row.organizationId.equals(context.organizationId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (branch == null) {
      throw const AuthorizationFailure(
        'The active branch is unavailable locally.',
      );
    }
  }

  Future<db.StockLocation> _requireLocation(
    BusinessContext context,
    String id,
    int? version,
  ) async {
    final row =
        await (database.select(database.stockLocations)..where(
              (row) =>
                  row.id.equals(id) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw const AuthorizationFailure(
        'The location is outside the active branch.',
      );
    }
    if (version == null || version < 0 || row.version != version) {
      throw const ConflictFailure(
        'The location changed. Refresh before trying again.',
      );
    }
    return row;
  }

  Future<void> _requireNoPending(
    BusinessContext context, {
    required bool locationsOnly,
  }) async {
    final query = database.select(database.syncOutboxEntries)
      ..where(
        (row) =>
            row.organizationId.equals(context.organizationId) &
            row.branchId.equals(context.branchId) &
            row.status.isNotIn(const ['succeeded', 'discarded']),
      );
    if (locationsOnly) {
      query.where((row) => row.aggregateType.equals('stock_location'));
    }
    final pending = await (query..limit(1)).getSingleOrNull();
    if (pending != null) {
      throw const ConflictFailure(
        'Synchronize or resolve pending branch operations before changing this location.',
      );
    }
  }

  Future<void> _requireNoWork(BusinessContext context, String id) async {
    final row = await database
        .customSelect(
          '''
SELECT EXISTS(SELECT 1 FROM stock_counts WHERE organization_id = ? AND branch_id = ?
  AND stock_location_id = ? AND status = 'in_progress') AS has_count,
EXISTS(SELECT 1 FROM stock_transfer_items i JOIN stock_transfers t ON t.id = i.transfer_id
  AND t.organization_id = i.organization_id WHERE i.organization_id = ?
  AND (i.source_stock_location_id = ? OR i.destination_stock_location_id = ? OR i.damaged_stock_location_id = ?)
  AND t.status IN ('draft', 'submitted', 'approved', 'shipped')) AS has_transfer
''',
          variables: [
            Variable(context.organizationId),
            Variable(context.branchId),
            Variable(id),
            Variable(context.organizationId),
            Variable(id),
            Variable(id),
            Variable(id),
          ],
          readsFrom: {
            database.stockCounts,
            database.stockTransfers,
            database.stockTransferItems,
          },
        )
        .getSingle();
    if (row.read<bool>('has_count') || row.read<bool>('has_transfer')) {
      throw const ValidationFailure(
        'Finish active stock counts and transfers before changing this location.',
      );
    }
  }

  AuditLogEntry _audit(
    BusinessContext context,
    String operation,
    String id,
    AuditActionType action,
    Map<String, Object?> metadata,
    DateTime now,
  ) => AuditLogEntry(
    id: ids.newId(),
    organizationId: context.organizationId,
    branchId: context.branchId,
    actorUserId: context.actorUserId,
    operationId: operation,
    actionType: action,
    entityName: 'stock_location',
    entityId: id,
    metadata: metadata,
    createdAt: now,
  );
  OutboxCommand _command(
    BusinessContext context,
    String operation,
    String id,
    String type,
    Map<String, Object?> payload,
    DateTime now,
  ) => OutboxCommand(
    operationId: operation,
    organizationId: context.organizationId,
    branchId: context.branchId,
    actorUserId: context.actorUserId,
    commandType: type,
    aggregateType: 'stock_location',
    aggregateId: id,
    payload: payload,
    createdAt: now,
  );
}
