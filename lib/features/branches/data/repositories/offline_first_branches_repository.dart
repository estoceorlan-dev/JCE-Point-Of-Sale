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
import '../../domain/entities/branch_profile.dart';
import '../../domain/repositories/branches_repository.dart';

class OfflineFirstBranchesRepository implements BranchAdministrationRepository {
  const OfflineFirstBranchesRepository({
    required db.AppDatabase database,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _database = database,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock;

  final db.AppDatabase _database;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  Future<bool> _codeExists(
    String organizationId,
    String code, {
    String? exceptId,
  }) async {
    final row = await _database
        .customSelect(
          'SELECT id FROM branches WHERE organization_id = ? AND upper(trim(code)) = ? '
          '${exceptId == null ? '' : 'AND id <> ? '}LIMIT 1',
          variables: [
            Variable.withString(organizationId),
            Variable.withString(code),
            if (exceptId != null) Variable.withString(exceptId),
          ],
          readsFrom: {_database.branches},
        )
        .getSingleOrNull();
    return row != null;
  }

  @override
  Stream<List<BranchProfile>> watchBranches({
    required BusinessContext context,
    BranchQuery query = const BranchQuery(),
  }) {
    final statement = _database.select(_database.branches)
      ..where((row) => row.organizationId.equals(context.organizationId))
      ..orderBy([(row) => OrderingTerm.asc(row.name)]);
    if (!query.includeArchived) {
      statement.where(
        (row) => row.isActive.equals(true) & row.deletedAt.isNull(),
      );
    }
    final search = query.search.trim().toLowerCase();
    return _database
        .customSelect(
          '''
      SELECT b.id,
        (SELECT count(DISTINCT a.user_id) FROM user_role_assignments a
         JOIN app_users u ON u.id = a.user_id AND u.status = 'active' AND u.deleted_at IS NULL
         JOIN roles r ON r.id = a.role_id AND r.is_active = 1 AND r.deleted_at IS NULL
         WHERE a.organization_id = b.organization_id AND a.revoked_at IS NULL
           AND (a.branch_id = b.id OR a.branch_id IS NULL)) AS staff_count,
        (SELECT count(*) FROM registers r WHERE r.organization_id = b.organization_id
         AND r.branch_id = b.id AND r.is_active = 1 AND r.deleted_at IS NULL) AS register_count,
        (SELECT count(*) FROM sync_outbox q WHERE q.organization_id = b.organization_id
         AND ((q.aggregate_type = 'branch' AND q.aggregate_id = b.id) OR q.branch_id = b.id)
         AND q.status NOT IN ('succeeded', 'discarded')) AS pending_operations,
        (SELECT count(*) FROM shifts s WHERE s.organization_id = b.organization_id
         AND s.branch_id = b.id AND s.status = 'open') AS open_shifts
      FROM branches b WHERE b.organization_id = ?
    ''',
          variables: [Variable.withString(context.organizationId)],
          readsFrom: {
            _database.branches,
            _database.userRoleAssignments,
            _database.appUsers,
            _database.roles,
            _database.registers,
            _database.syncOutboxEntries,
            _database.shifts,
          },
        )
        .watch()
        .asyncMap((summaries) async {
          final counts = {
            for (final row in summaries) row.read<String>('id'): row,
          };
          final rows = await statement.get();
          return rows
              .map((row) => _map(row, counts[row.id]))
              .where(
                (branch) =>
                    search.isEmpty ||
                    branch.name.toLowerCase().contains(search) ||
                    branch.code.toLowerCase().contains(search) ||
                    (branch.city?.toLowerCase().contains(search) ?? false),
              )
              .toList(growable: false);
        });
  }

  @override
  Future<BranchProfile?> getBranch({
    required BusinessContext context,
    required String branchId,
  }) async {
    final row =
        await (_database.select(_database.branches)..where(
              (row) =>
                  row.id.equals(branchId) &
                  row.organizationId.equals(context.organizationId),
            ))
            .getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<Result<String, Failure>> createBranch({
    required BusinessContext context,
    required BranchDraft draft,
  }) async {
    final value = draft.normalized();
    if (await _codeExists(context.organizationId, value.code)) {
      return const Result.failure(
        ConflictFailure('A branch with this code already exists.'),
      );
    }
    final id = _idGenerator.newId();
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await database
            .into(database.branches)
            .insert(
              db.BranchesCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                code: value.code,
                name: value.name,
                timezone: Value(value.timezone),
                addressLineOne: Value(value.addressLineOne),
                addressLineTwo: Value(value.addressLineTwo),
                city: Value(value.city),
                province: Value(value.province),
                postalCode: Value(value.postalCode),
                phone: Value(value.phone),
                email: Value(value.email),
                receiptDisplayName: Value(value.receiptDisplayName),
                createdAt: now,
                updatedAt: now,
              ),
            );
        return id;
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.create,
        id,
        _payload(id, value),
        now,
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'branch.create',
        id,
        _payload(id, value),
        now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> updateBranch({
    required BusinessContext context,
    required String branchId,
    required BranchDraft draft,
    required int expectedVersion,
  }) async {
    final value = draft.normalized();
    if (await _codeExists(
      context.organizationId,
      value.code,
      exceptId: branchId,
    )) {
      return const Result.failure(
        ConflictFailure('A branch with this code already exists.'),
      );
    }
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final updated =
            await (database.update(database.branches)..where(
                  (row) =>
                      row.id.equals(branchId) &
                      row.organizationId.equals(context.organizationId) &
                      row.isActive.equals(true) &
                      row.deletedAt.isNull() &
                      row.version.equals(expectedVersion),
                ))
                .write(
                  db.BranchesCompanion(
                    code: Value(value.code),
                    name: Value(value.name),
                    timezone: Value(value.timezone),
                    addressLineOne: Value(value.addressLineOne),
                    addressLineTwo: Value(value.addressLineTwo),
                    city: Value(value.city),
                    province: Value(value.province),
                    postalCode: Value(value.postalCode),
                    phone: Value(value.phone),
                    email: Value(value.email),
                    receiptDisplayName: Value(value.receiptDisplayName),
                    version: Value(expectedVersion + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const ConflictFailure(
            'The branch changed on another device. Refresh and retry.',
          );
        }
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.update,
        branchId,
        _payload(branchId, value),
        now,
      ),
      outboxCommand: _outbox(context, operationId, 'branch.update', branchId, {
        ..._payload(branchId, value),
        'expectedVersion': expectedVersion,
      }, now),
    );
  }

  @override
  Future<Result<void, Failure>> setBranchArchived({
    required BusinessContext context,
    required String branchId,
    required bool archived,
    required int expectedVersion,
  }) async {
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        if (archived) {
          final guard = await _archiveGuard(context, branchId);
          if (guard != null) throw guard;
        }
        final updated =
            await (database.update(database.branches)..where(
                  (row) =>
                      row.id.equals(branchId) &
                      row.organizationId.equals(context.organizationId) &
                      row.version.equals(expectedVersion),
                ))
                .write(
                  db.BranchesCompanion(
                    isActive: Value(!archived),
                    deletedAt: Value(archived ? now : null),
                    version: Value(expectedVersion + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const ConflictFailure('The branch changed. Refresh and retry.');
        }
      },
      auditEntry: _audit(
        context,
        operationId,
        archived ? AuditActionType.delete : AuditActionType.update,
        branchId,
        {'archived': archived},
        now,
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        archived ? 'branch.archive' : 'branch.restore',
        branchId,
        {'expectedVersion': expectedVersion},
        now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> updateBranchName({
    required BusinessContext context,
    required String name,
  }) async {
    final current = await getBranch(
      context: context,
      branchId: context.branchId,
    );
    if (current == null) {
      return const Result.failure(
        ValidationFailure('The active branch is not cached locally.'),
      );
    }
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final changed =
            await (database.update(database.branches)..where(
                  (row) =>
                      row.id.equals(current.id) &
                      row.organizationId.equals(context.organizationId) &
                      row.isActive.equals(true) &
                      row.deletedAt.isNull(),
                ))
                .write(
                  db.BranchesCompanion(
                    name: Value(name),
                    version: Value(current.version + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) {
          throw const ConflictFailure('The active branch is unavailable.');
        }
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.update,
        current.id,
        {'name': name},
        now,
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'branch.update_name',
        current.id,
        {'name': name},
        now,
      ),
    );
  }

  Future<Failure?> _archiveGuard(
    BusinessContext context,
    String branchId,
  ) async {
    if (branchId == context.branchId) {
      return const ValidationFailure(
        'Switch to another branch before archiving this branch.',
      );
    }
    final active =
        await (_database.select(_database.branches)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .get();
    if (active.length <= 1) {
      return const ValidationFailure(
        'The organization must keep one active branch.',
      );
    }
    final openShift =
        await (_database.select(_database.shifts)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(branchId) &
                    row.status.equals('open'),
              )
              ..limit(1))
            .getSingleOrNull();
    if (openShift != null) {
      return const ValidationFailure('Close all branch shifts first.');
    }
    final openCount =
        await (_database.select(_database.stockCounts)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(branchId) &
                    row.status.equals('in_progress'),
              )
              ..limit(1))
            .getSingleOrNull();
    if (openCount != null) {
      return const ValidationFailure(
        'Complete or cancel active stock counts first.',
      );
    }
    final transfer =
        await (_database.select(_database.stockTransfers)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    (row.sourceBranchId.equals(branchId) |
                        row.destinationBranchId.equals(branchId)) &
                    row.status.isIn([
                      'draft',
                      'submitted',
                      'approved',
                      'shipped',
                    ]),
              )
              ..limit(1))
            .getSingleOrNull();
    if (transfer != null) {
      return const ValidationFailure(
        'Resolve in-flight stock transfers first.',
      );
    }
    final pending =
        await (_database.select(_database.syncOutboxEntries)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    (row.branchId.equals(branchId) |
                        (row.aggregateType.equals('branch') &
                            row.aggregateId.equals(branchId))) &
                    row.status.isNotIn(const ['succeeded', 'discarded']),
              )
              ..limit(1))
            .getSingleOrNull();
    if (pending != null) {
      return const ValidationFailure(
        'Synchronize or resolve pending branch operations first.',
      );
    }
    return null;
  }

  BranchProfile _map(db.Branche row, [QueryRow? summary]) => BranchProfile(
    id: row.id,
    organizationId: row.organizationId,
    code: row.code,
    name: row.name,
    timezone: row.timezone,
    addressLineOne: row.addressLineOne,
    addressLineTwo: row.addressLineTwo,
    city: row.city,
    province: row.province,
    postalCode: row.postalCode,
    phone: row.phone,
    email: row.email,
    receiptDisplayName: row.receiptDisplayName,
    isActive: row.isActive && row.deletedAt == null,
    version: row.version,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    staffCount: summary?.read<int>('staff_count') ?? 0,
    registerCount: summary?.read<int>('register_count') ?? 0,
    pendingOperations: summary?.read<int>('pending_operations') ?? 0,
    openShifts: summary?.read<int>('open_shifts') ?? 0,
  );

  Map<String, Object?> _payload(String id, BranchDraft draft) => {
    'id': id,
    'code': draft.code,
    'name': draft.name,
    'timezone': draft.timezone,
    'addressLineOne': draft.addressLineOne,
    'addressLineTwo': draft.addressLineTwo,
    'city': draft.city,
    'province': draft.province,
    'postalCode': draft.postalCode,
    'phone': draft.phone,
    'email': draft.email,
    'receiptDisplayName': draft.receiptDisplayName,
  };

  AuditLogEntry _audit(
    BusinessContext context,
    String operationId,
    AuditActionType action,
    String entityId,
    Map<String, Object?> metadata,
    DateTime now,
  ) => AuditLogEntry(
    id: _idGenerator.newId(),
    operationId: operationId,
    organizationId: context.organizationId,
    actorUserId: context.actorUserId,
    branchId: context.branchId,
    actionType: action,
    entityName: 'branch',
    entityId: entityId,
    metadata: metadata,
    createdAt: now,
  );

  OutboxCommand _outbox(
    BusinessContext context,
    String operationId,
    String commandType,
    String aggregateId,
    Map<String, Object?> payload,
    DateTime now,
  ) => OutboxCommand(
    operationId: operationId,
    organizationId: context.organizationId,
    branchId: context.branchId,
    actorUserId: context.actorUserId,
    commandType: commandType,
    aggregateType: 'branch',
    aggregateId: aggregateId,
    payload: payload,
    createdAt: now,
  );
}
