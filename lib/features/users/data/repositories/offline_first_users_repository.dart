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
import '../../../../shared/models/permission.dart';
import '../../../../shared/models/user_account_status.dart';
import '../../domain/entities/staff_account.dart';
import '../../domain/repositories/users_repository.dart';
import '../services/staff_access_guard.dart';

class OfflineFirstUsersRepository implements UsersRepository {
  const OfflineFirstUsersRepository({
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

  @override
  Stream<List<StaffAccount>> watchUsers({required BusinessContext context}) {
    return _database
        .customSelect(
          '''
SELECT au.id AS user_id, au.organization_id, au.firebase_uid, au.email,
       au.display_name, au.status, au.invited_at, au.activated_at,
       au.version AS user_version, au.created_at, au.updated_at,
       ura.id AS assignment_id, ura.branch_id, ura.role_id,
       ura.version AS assignment_version, r.name AS role_name,
       b.name AS branch_name,
       coalesce(pending.operation_count, 0) AS pending_operations
FROM app_users au
LEFT JOIN user_role_assignments ura
  ON ura.user_id = au.id AND ura.revoked_at IS NULL
LEFT JOIN roles r ON r.id = ura.role_id
LEFT JOIN branches b ON b.id = ura.branch_id
LEFT JOIN (
  SELECT aggregate_id, count(*) AS operation_count FROM sync_outbox
  WHERE organization_id = ? AND aggregate_type = 'app_user'
    AND status NOT IN ('succeeded', 'discarded')
  GROUP BY aggregate_id
) pending ON pending.aggregate_id = au.id
WHERE au.organization_id = ? AND au.deleted_at IS NULL
ORDER BY lower(au.display_name), au.id, ura.branch_id, r.name
''',
          variables: [
            Variable<String>(context.organizationId),
            Variable<String>(context.organizationId),
          ],
          readsFrom: {
            _database.appUsers,
            _database.userRoleAssignments,
            _database.roles,
            _database.branches,
            _database.syncOutboxEntries,
          },
        )
        .watch()
        .map(_mapStaffRows);
  }

  List<StaffAccount> _mapStaffRows(List<QueryRow> rows) {
    final grouped = <String, List<QueryRow>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.read<String>('user_id'), () => []).add(row);
    }
    return [
      for (final entry in grouped.entries)
        StaffAccount(
          id: entry.key,
          organizationId: entry.value.first.read<String>('organization_id'),
          firebaseUid: entry.value.first.readNullable<String>('firebase_uid'),
          email: entry.value.first.read<String>('email'),
          displayName: entry.value.first.read<String>('display_name'),
          status: UserAccountStatus.parse(
            entry.value.first.read<String>('status'),
          ),
          assignments: [
            for (final row in entry.value)
              if (row.readNullable<String>('assignment_id') case final id?)
                StaffAssignment(
                  id: id,
                  userId: entry.key,
                  roleId: row.read<String>('role_id'),
                  roleName:
                      row.readNullable<String>('role_name') ?? 'Unknown role',
                  branchId: row.readNullable<String>('branch_id'),
                  branchName: row.readNullable<String>('branch_name'),
                  version: row.readNullable<int>('assignment_version') ?? 0,
                ),
          ],
          version: entry.value.first.read<int>('user_version'),
          createdAt: entry.value.first.read<DateTime>('created_at'),
          updatedAt: entry.value.first.read<DateTime>('updated_at'),
          invitedAt: entry.value.first.readNullable<DateTime>('invited_at'),
          activatedAt: entry.value.first.readNullable<DateTime>('activated_at'),
          pendingOperations: entry.value.first.read<int>('pending_operations'),
        ),
    ];
  }

  @override
  Stream<List<RoleDefinition>> watchRoles({
    required BusinessContext context,
    bool includeArchived = false,
  }) {
    return _database
        .customSelect(
          '''
SELECT r.id, r.organization_id, r.code, r.name, r.description, r.is_active,
       r.version, rp.permission_code,
       (SELECT count(*) FROM user_role_assignments ura
          WHERE ura.role_id = r.id AND ura.revoked_at IS NULL) assignment_count
FROM roles r
LEFT JOIN role_permissions rp ON rp.role_id = r.id
WHERE r.organization_id = ? ${includeArchived ? '' : 'AND r.is_active = 1 AND r.deleted_at IS NULL'}
ORDER BY lower(r.name), r.id, rp.permission_code
''',
          variables: [Variable<String>(context.organizationId)],
          readsFrom: {
            _database.roles,
            _database.rolePermissions,
            _database.userRoleAssignments,
          },
        )
        .watch()
        .map((rows) {
          final grouped = <String, List<QueryRow>>{};
          for (final row in rows) {
            grouped.putIfAbsent(row.read<String>('id'), () => []).add(row);
          }
          return [
            for (final entry in grouped.entries)
              RoleDefinition(
                id: entry.key,
                organizationId: entry.value.first.read<String>(
                  'organization_id',
                ),
                code: entry.value.first.read<String>('code'),
                name: entry.value.first.read<String>('name'),
                description: entry.value.first.readNullable<String>(
                  'description',
                ),
                permissions: {
                  for (final row in entry.value)
                    if (row.readNullable<String>('permission_code')
                        case final code?)
                      if (AppPermission.fromCode(code) case final permission?)
                        permission,
                },
                isActive: entry.value.first.read<bool>('is_active'),
                version: entry.value.first.read<int>('version'),
                assignmentCount: entry.value.first.read<int>(
                  'assignment_count',
                ),
              ),
          ];
        });
  }

  @override
  Future<Result<String, Failure>> inviteUser({
    required BusinessContext context,
    required StaffDraft draft,
  }) async {
    final email = draft.email.trim().toLowerCase();
    final displayName = draft.displayName.trim();
    final validation = await _validateStaffDraft(
      context,
      email,
      displayName,
      draft.assignments,
    );
    if (validation != null) return Result.failure(validation);
    final duplicate =
        await (_database.select(_database.appUsers)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.email.equals(email),
            ))
            .getSingleOrNull();
    if (duplicate != null) {
      return const Result.failure(
        ConflictFailure('A staff account with this email already exists.'),
      );
    }
    final id = _idGenerator.newId();
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    final assignments = [
      for (final assignment in _deduplicateAssignments(draft.assignments))
        (
          id: _idGenerator.newId(),
          roleId: assignment.roleId,
          branchId: assignment.branchId,
        ),
    ];
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await database
            .into(database.appUsers)
            .insert(
              db.AppUsersCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                firebaseUid: const Value(null),
                email: email,
                displayName: displayName,
                status: UserAccountStatus.invited.name,
                invitedAt: Value(now),
                createdAt: now,
                updatedAt: now,
              ),
            );
        for (final assignment in assignments) {
          await database
              .into(database.userRoleAssignments)
              .insert(
                db.UserRoleAssignmentsCompanion.insert(
                  id: assignment.id,
                  organizationId: context.organizationId,
                  branchId: Value(assignment.branchId),
                  userId: id,
                  roleId: assignment.roleId,
                  assignedAt: now,
                  updatedAt: Value(now),
                ),
              );
        }
        return id;
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.create,
        'app_user',
        id,
        {'email': email, 'status': UserAccountStatus.invited.name},
        now,
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'user.invite',
        'app_user',
        id,
        {
          'id': id,
          'email': email,
          'displayName': displayName,
          'assignments': [
            for (final assignment in assignments)
              {
                'id': assignment.id,
                'roleId': assignment.roleId,
                'branchId': assignment.branchId,
              },
          ],
        },
        now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> updateUser({
    required BusinessContext context,
    required String userId,
    required String displayName,
    required String email,
    required int expectedVersion,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = displayName.trim();
    final validation = await _validateStaffDraft(
      context,
      normalizedEmail,
      normalizedName,
      const [],
      requireAssignments: false,
    );
    if (validation != null) return Result.failure(validation);
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final updated =
            await (database.update(database.appUsers)..where(
                  (row) =>
                      row.id.equals(userId) &
                      row.organizationId.equals(context.organizationId) &
                      row.version.equals(expectedVersion),
                ))
                .write(
                  db.AppUsersCompanion(
                    email: Value(normalizedEmail),
                    displayName: Value(normalizedName),
                    version: Value(expectedVersion + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const ConflictFailure(
            'The staff account changed. Refresh and retry.',
          );
        }
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.update,
        'app_user',
        userId,
        {'email': normalizedEmail, 'displayName': normalizedName},
        now,
      ),
      outboxCommand:
          _outbox(context, operationId, 'user.update', 'app_user', userId, {
            'email': normalizedEmail,
            'displayName': normalizedName,
            'expectedVersion': expectedVersion,
          }, now),
    );
  }

  @override
  Future<Result<void, Failure>> replaceAssignments({
    required BusinessContext context,
    required String userId,
    required List<StaffAssignmentDraft> assignments,
  }) async {
    final validation = await _validateAssignments(context, assignments);
    if (validation != null) return Result.failure(validation);
    if (await _wouldRemoveLastAdministrator(context, userId, assignments)) {
      return const Result.failure(
        ValidationFailure(
          'This change would remove the last full organization administrator.',
        ),
      );
    }
    final values = [
      for (final assignment in _deduplicateAssignments(assignments))
        (
          id: _idGenerator.newId(),
          roleId: assignment.roleId,
          branchId: assignment.branchId,
        ),
    ];
    final payload = <String, Object?>{
      'assignments': [
        for (final assignment in values)
          {
            'id': assignment.id,
            'roleId': assignment.roleId,
            'branchId': assignment.branchId,
          },
      ],
    };
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) =>
          StaffAccessGuard(database).run(context, () async {
            final target =
                await (database.select(database.appUsers)..where(
                      (row) =>
                          row.id.equals(userId) &
                          row.organizationId.equals(context.organizationId),
                    ))
                    .getSingleOrNull();
            if (target == null || target.deletedAt != null) {
              throw const AuthorizationFailure(
                'The staff account is unavailable in this organization.',
              );
            }
            payload['expectedVersion'] = target.version;
            await (database.update(
              database.appUsers,
            )..where((row) => row.id.equals(target.id))).write(
              db.AppUsersCompanion(
                version: Value(target.version + 1),
                updatedAt: Value(now),
              ),
            );
            final existing =
                await (database.select(database.userRoleAssignments)..where(
                      (row) =>
                          row.organizationId.equals(context.organizationId) &
                          row.userId.equals(userId) &
                          row.revokedAt.isNull(),
                    ))
                    .get();
            for (final assignment in existing) {
              await (database.update(
                database.userRoleAssignments,
              )..where((row) => row.id.equals(assignment.id))).write(
                db.UserRoleAssignmentsCompanion(
                  revokedAt: Value(now),
                  updatedAt: Value(now),
                  version: Value(assignment.version + 1),
                ),
              );
            }
            for (final assignment in values) {
              await database
                  .into(database.userRoleAssignments)
                  .insert(
                    db.UserRoleAssignmentsCompanion.insert(
                      id: assignment.id,
                      organizationId: context.organizationId,
                      branchId: Value(assignment.branchId),
                      userId: userId,
                      roleId: assignment.roleId,
                      assignedAt: now,
                      updatedAt: Value(now),
                    ),
                  );
            }
          }),
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.roleChange,
        'app_user',
        userId,
        {'assignmentCount': values.length},
        now,
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'user.assignments.replace',
        'app_user',
        userId,
        payload,
        now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> setUserStatus({
    required BusinessContext context,
    required String userId,
    required UserAccountStatus status,
    required int expectedVersion,
  }) async {
    if (status != UserAccountStatus.active &&
        await _wouldRemoveLastAdministrator(context, userId, const [])) {
      return const Result.failure(
        ValidationFailure(
          'The last full organization administrator cannot be disabled.',
        ),
      );
    }
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) =>
          StaffAccessGuard(database).run(context, () async {
            final updated =
                await (database.update(database.appUsers)..where(
                      (row) =>
                          row.id.equals(userId) &
                          row.organizationId.equals(context.organizationId) &
                          row.version.equals(expectedVersion),
                    ))
                    .write(
                      db.AppUsersCompanion(
                        status: Value(status.name),
                        activatedAt: status == UserAccountStatus.active
                            ? Value(now)
                            : const Value.absent(),
                        version: Value(expectedVersion + 1),
                        updatedAt: Value(now),
                      ),
                    );
            if (updated != 1) {
              throw const ConflictFailure(
                'The staff account changed. Refresh and retry.',
              );
            }
            if (status == UserAccountStatus.suspended ||
                status == UserAccountStatus.disabled) {
              final assignments =
                  await (database.select(database.userRoleAssignments)..where(
                        (row) =>
                            row.organizationId.equals(context.organizationId) &
                            row.userId.equals(userId) &
                            row.revokedAt.isNull(),
                      ))
                      .get();
              for (final assignment in assignments) {
                await (database.update(
                  database.userRoleAssignments,
                )..where((row) => row.id.equals(assignment.id))).write(
                  db.UserRoleAssignmentsCompanion(
                    revokedAt: Value(now),
                    updatedAt: Value(now),
                    version: Value(assignment.version + 1),
                  ),
                );
              }
            }
          }),
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.update,
        'app_user',
        userId,
        {'status': status.name},
        now,
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'user.status.set',
        'app_user',
        userId,
        {'status': status.name, 'expectedVersion': expectedVersion},
        now,
      ),
    );
  }

  @override
  Future<Result<String, Failure>> createRole({
    required BusinessContext context,
    required RoleDraft draft,
  }) async {
    final value = _normalizeRole(draft);
    final validation = _validateRole(value);
    if (validation != null) return Result.failure(validation);
    final id = _idGenerator.newId();
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await database
            .into(database.roles)
            .insert(
              db.RolesCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                code: value.code,
                name: value.name,
                description: Value(value.description),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _replaceRolePermissions(database, id, value.permissions, now);
        return id;
      },
      auditEntry:
          _audit(context, operationId, AuditActionType.create, 'role', id, {
            'code': value.code,
            'permissions': value.permissions.map((item) => item.code).toList(),
          }, now),
      outboxCommand: _outbox(
        context,
        operationId,
        'role.create',
        'role',
        id,
        _rolePayload(id, value),
        now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> updateRole({
    required BusinessContext context,
    required String roleId,
    required RoleDraft draft,
    required int expectedVersion,
  }) async {
    final value = _normalizeRole(draft);
    final validation = _validateRole(value);
    if (validation != null) return Result.failure(validation);
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) => StaffAccessGuard(database).run(
        context,
        () async {
          final updated =
              await (database.update(database.roles)..where(
                    (row) =>
                        row.id.equals(roleId) &
                        row.organizationId.equals(context.organizationId) &
                        row.version.equals(expectedVersion),
                  ))
                  .write(
                    db.RolesCompanion(
                      code: Value(value.code),
                      name: Value(value.name),
                      description: Value(value.description),
                      version: Value(expectedVersion + 1),
                      updatedAt: Value(now),
                    ),
                  );
          if (updated != 1) {
            throw const ConflictFailure('The role changed. Refresh and retry.');
          }
          await _replaceRolePermissions(
            database,
            roleId,
            value.permissions,
            now,
          );
        },
      ),
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.roleChange,
        'role',
        roleId,
        {'permissions': value.permissions.map((item) => item.code).toList()},
        now,
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'role.update',
        'role',
        roleId,
        {..._rolePayload(roleId, value), 'expectedVersion': expectedVersion},
        now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> setRoleArchived({
    required BusinessContext context,
    required String roleId,
    required bool archived,
    required int expectedVersion,
  }) async {
    final activeAssignment =
        await (_database.select(_database.userRoleAssignments)
              ..where(
                (row) => row.roleId.equals(roleId) & row.revokedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (archived && activeAssignment != null) {
      return const Result.failure(
        ValidationFailure('Reassign staff before archiving this role.'),
      );
    }
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) => StaffAccessGuard(database).run(
        context,
        () async {
          final updated =
              await (database.update(database.roles)..where(
                    (row) =>
                        row.id.equals(roleId) &
                        row.organizationId.equals(context.organizationId) &
                        row.version.equals(expectedVersion),
                  ))
                  .write(
                    db.RolesCompanion(
                      isActive: Value(!archived),
                      deletedAt: Value(archived ? now : null),
                      version: Value(expectedVersion + 1),
                      updatedAt: Value(now),
                    ),
                  );
          if (updated != 1) {
            throw const ConflictFailure('The role changed. Refresh and retry.');
          }
        },
      ),
      auditEntry: _audit(
        context,
        operationId,
        archived ? AuditActionType.delete : AuditActionType.update,
        'role',
        roleId,
        {'archived': archived},
        now,
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        archived ? 'role.archive' : 'role.restore',
        'role',
        roleId,
        {'expectedVersion': expectedVersion},
        now,
      ),
    );
  }

  Future<Failure?> _validateStaffDraft(
    BusinessContext context,
    String email,
    String name,
    List<StaffAssignmentDraft> assignments, {
    bool requireAssignments = true,
  }) async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return const ValidationFailure('Enter a valid email address.');
    }
    if (name.length < 2 || name.length > 80) {
      return const ValidationFailure(
        'Display name must contain 2–80 characters.',
      );
    }
    if (requireAssignments && assignments.isEmpty) {
      return const ValidationFailure('Assign at least one role.');
    }
    return _validateAssignments(context, assignments);
  }

  Future<Failure?> _validateAssignments(
    BusinessContext context,
    List<StaffAssignmentDraft> assignments,
  ) async {
    for (final assignment in _deduplicateAssignments(assignments)) {
      final role =
          await (_database.select(_database.roles)..where(
                (row) =>
                    row.id.equals(assignment.roleId) &
                    row.organizationId.equals(context.organizationId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (role == null) {
        return const ValidationFailure('A selected role is unavailable.');
      }
      final branchId = assignment.branchId;
      if (branchId != null) {
        final branch =
            await (_database.select(_database.branches)..where(
                  (row) =>
                      row.id.equals(branchId) &
                      row.organizationId.equals(context.organizationId) &
                      row.isActive.equals(true) &
                      row.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (branch == null) {
          return const ValidationFailure('A selected branch is unavailable.');
        }
      }
    }
    return null;
  }

  List<StaffAssignmentDraft> _deduplicateAssignments(
    List<StaffAssignmentDraft> values,
  ) {
    final found = <String>{};
    return [
      for (final value in values)
        if (found.add('${value.roleId}|${value.branchId ?? '*'}')) value,
    ];
  }

  Future<bool> _wouldRemoveLastAdministrator(
    BusinessContext context,
    String targetUserId,
    List<StaffAssignmentDraft> replacement,
  ) async {
    final replacementRoleIds = replacement
        .where((item) => item.branchId == null)
        .map((item) => item.roleId)
        .toSet();
    final replacementPermissions = <String>{};
    if (replacementRoleIds.isNotEmpty) {
      final grants = await (_database.select(
        _database.rolePermissions,
      )..where((row) => row.roleId.isIn(replacementRoleIds))).get();
      replacementPermissions.addAll(grants.map((item) => item.permissionCode));
    }
    const required = {'users.manage', 'roles.manage', 'branches.manage'};
    if (replacementPermissions.containsAll(required)) return false;
    final rows = await _database
        .customSelect(
          '''SELECT ura.user_id, count(DISTINCT rp.permission_code) permission_count
         FROM user_role_assignments ura
         JOIN roles r ON r.id = ura.role_id AND r.is_active = 1 AND r.deleted_at IS NULL
         JOIN role_permissions rp ON rp.role_id = r.id
         JOIN app_users au ON au.id = ura.user_id AND au.status = 'active' AND au.deleted_at IS NULL
         WHERE ura.organization_id = ? AND ura.branch_id IS NULL AND ura.revoked_at IS NULL
           AND ura.user_id <> ? AND rp.permission_code IN ('users.manage','roles.manage','branches.manage')
         GROUP BY ura.user_id HAVING count(DISTINCT rp.permission_code) = 3''',
          variables: [
            Variable<String>(context.organizationId),
            Variable<String>(targetUserId),
          ],
          readsFrom: {
            _database.userRoleAssignments,
            _database.roles,
            _database.rolePermissions,
            _database.appUsers,
          },
        )
        .get();
    return rows.isEmpty;
  }

  RoleDraft _normalizeRole(RoleDraft value) => RoleDraft(
    code: value.code.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]+'),
      '_',
    ),
    name: value.name.trim(),
    description: value.description?.trim().isEmpty ?? true
        ? null
        : value.description!.trim(),
    permissions: value.permissions,
  );

  Failure? _validateRole(RoleDraft value) {
    if (!RegExp(r'^[a-z][a-z0-9_]{1,39}$').hasMatch(value.code)) {
      return const ValidationFailure(
        'Role code must be 2–40 lowercase letters, numbers, or underscores.',
      );
    }
    if (value.name.length < 2 || value.name.length > 80) {
      return const ValidationFailure('Role name must contain 2–80 characters.');
    }
    if (value.permissions.isEmpty) {
      return const ValidationFailure('Select at least one permission.');
    }
    return null;
  }

  Future<void> _replaceRolePermissions(
    db.AppDatabase database,
    String roleId,
    Set<AppPermission> permissions,
    DateTime now,
  ) async {
    await (database.delete(
      database.rolePermissions,
    )..where((row) => row.roleId.equals(roleId))).go();
    for (final permission in permissions) {
      await database
          .into(database.permissions)
          .insertOnConflictUpdate(
            db.PermissionsCompanion.insert(
              code: permission.code,
              name: permission.name,
              createdAt: now,
            ),
          );
      await database
          .into(database.rolePermissions)
          .insert(
            db.RolePermissionsCompanion.insert(
              roleId: roleId,
              permissionCode: permission.code,
              grantedAt: now,
            ),
          );
    }
  }

  Map<String, Object?> _rolePayload(String id, RoleDraft value) => {
    'id': id,
    'code': value.code,
    'name': value.name,
    'description': value.description,
    'permissions': value.permissions.map((item) => item.code).toList(),
  };

  AuditLogEntry _audit(
    BusinessContext context,
    String operationId,
    AuditActionType action,
    String entityName,
    String entityId,
    Map<String, Object?> metadata,
    DateTime now,
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
    Map<String, Object?> payload,
    DateTime now,
  ) => OutboxCommand(
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
