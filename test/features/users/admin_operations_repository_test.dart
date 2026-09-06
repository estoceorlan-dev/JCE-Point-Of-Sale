import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/branches/data/repositories/offline_first_branches_repository.dart';
import 'package:jce_pos/features/branches/domain/entities/branch_profile.dart';
import 'package:jce_pos/features/users/data/repositories/offline_first_users_repository.dart';
import 'package:jce_pos/features/users/domain/entities/staff_account.dart';
import 'package:jce_pos/shared/models/business_context.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  late AppDatabase database;
  late OfflineFirstBranchesRepository branches;
  late OfflineFirstUsersRepository users;
  final now = DateTime.utc(2026, 9, 6);
  const context = BusinessContext(
    organizationId: 'org',
    branchId: 'main',
    actorUserId: 'admin',
  );
  const protected = {
    AppPermission.manageBranches,
    AppPermission.manageRoles,
    AppPermission.manageUsers,
  };
  Future<void> staff(String id, {String role = 'owner', String? branch}) async {
    await database
        .into(database.appUsers)
        .insert(
          AppUsersCompanion.insert(
            id: id,
            organizationId: 'org',
            email: '$id@example.test',
            displayName: id,
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.userRoleAssignments)
        .insert(
          UserRoleAssignmentsCompanion.insert(
            id: 'assignment-$id',
            organizationId: 'org',
            userId: id,
            roleId: role,
            branchId: Value(branch),
            assignedAt: now,
          ),
        );
  }

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final transaction = LocalMutationTransaction(database);
    final ids = _Ids();
    final clock = FixedAppClock(now);
    branches = OfflineFirstBranchesRepository(
      database: database,
      localMutationTransaction: transaction,
      idGenerator: ids,
      clock: clock,
    );
    users = OfflineFirstUsersRepository(
      database: database,
      localMutationTransaction: transaction,
      idGenerator: ids,
      clock: clock,
    );
    await database
        .into(database.organizations)
        .insert(
          OrganizationsCompanion.insert(
            id: 'org',
            code: 'ORG',
            name: 'Organization',
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final id in ['main', 'second']) {
      await database
          .into(database.branches)
          .insert(
            BranchesCompanion.insert(
              id: id,
              organizationId: 'org',
              code: id.toUpperCase(),
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    for (final id in ['owner', 'cashier']) {
      await database
          .into(database.roles)
          .insert(
            RolesCompanion.insert(
              id: id,
              organizationId: 'org',
              code: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    for (final permission in {...protected, AppPermission.processSales}) {
      await database
          .into(database.permissions)
          .insert(
            PermissionsCompanion.insert(
              code: permission.code,
              name: permission.name,
              createdAt: now,
            ),
          );
      await database
          .into(database.rolePermissions)
          .insert(
            RolePermissionsCompanion.insert(
              roleId: permission == AppPermission.processSales
                  ? 'cashier'
                  : 'owner',
              permissionCode: permission.code,
              grantedAt: now,
            ),
          );
    }
    await staff('admin');
  });
  tearDown(() => database.close());

  test(
    'legacy mixed-case and padded branch codes still block duplicates',
    () async {
      await (database.update(database.branches)
            ..where((row) => row.id.equals('second')))
          .write(const BranchesCompanion(code: Value(' second ')));
      final created = await branches.createBranch(
        context: context,
        draft: const BranchDraft(
          code: 'SECOND',
          name: 'Duplicate',
          timezone: 'Asia/Manila',
        ),
      );
      expect(created.failureOrNull, isA<ConflictFailure>());
      expect(await database.select(database.syncOutboxEntries).get(), isEmpty);
    },
  );

  test(
    'branch lifecycle preserves rows and queues an audit for every mutation',
    () async {
      final archived = await branches.setBranchArchived(
        context: context,
        branchId: 'second',
        archived: true,
        expectedVersion: 0,
      );
      expect(archived.failureOrNull, isNull);
      var branch = await branches.getBranch(
        context: context,
        branchId: 'second',
      );
      expect(branch!.isActive, isFalse);
      expect(branch.version, 1);
      final editedWhileArchived = await branches.updateBranch(
        context: context,
        branchId: 'second',
        expectedVersion: 1,
        draft: const BranchDraft(
          code: 'SECOND',
          name: 'Archived edit',
          timezone: 'Asia/Manila',
        ),
      );
      expect(editedWhileArchived.isFailure, isTrue);
      final restored = await branches.setBranchArchived(
        context: context,
        branchId: 'second',
        archived: false,
        expectedVersion: 1,
      );
      expect(restored.isSuccess, isTrue);
      branch = await branches.getBranch(context: context, branchId: 'second');
      expect(branch!.isActive, isTrue);
      expect(branch.version, 2);
      expect(await database.select(database.branches).get(), hasLength(2));
      expect(
        await database.select(database.localAuditLogs).get(),
        hasLength(2),
      );
      expect(
        await database.select(database.syncOutboxEntries).get(),
        hasLength(2),
      );
    },
  );
  test(
    'current branch, stale versions and pending operations block archival',
    () async {
      expect(
        (await branches.setBranchArchived(
          context: context,
          branchId: 'main',
          archived: true,
          expectedVersion: 0,
        )).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await branches.setBranchArchived(
          context: context,
          branchId: 'second',
          archived: true,
          expectedVersion: 8,
        )).failureOrNull,
        isA<ConflictFailure>(),
      );
      await branches.updateBranch(
        context: context,
        branchId: 'second',
        expectedVersion: 0,
        draft: const BranchDraft(
          code: 'SECOND',
          name: 'Second updated',
          timezone: 'Asia/Manila',
        ),
      );
      final pending = await branches.setBranchArchived(
        context: context,
        branchId: 'second',
        archived: true,
        expectedVersion: 1,
      );
      expect(pending.failureOrNull?.message, contains('pending'));
      expect(
        await database.select(database.localAuditLogs).get(),
        hasLength(1),
      );
    },
  );
  test(
    'new offline branch retains operational profile and is marked pending',
    () async {
      final created = await branches.createBranch(
        context: context,
        draft: const BranchDraft(
          code: 'NEW',
          name: 'New Branch',
          timezone: 'Asia/Manila',
          addressLineOne: '1 Main Street',
          city: 'Quezon City',
          phone: '+63 912 345 6789',
          receiptDisplayName: 'JCE New',
        ),
      );
      expect(created.failureOrNull, isNull);
      final rows = await branches.watchBranches(context: context).first;
      final row = rows.singleWhere((row) => row.id == created.valueOrNull);
      expect(row.addressLineOne, '1 Main Street');
      expect(row.receiptDisplayName, 'JCE New');
      expect(row.pendingOperations, 1);
      final duplicate = await branches.createBranch(
        context: context,
        draft: const BranchDraft(
          code: ' new ',
          name: 'Duplicate',
          timezone: 'Asia/Manila',
        ),
      );
      expect(duplicate.failureOrNull, isA<ConflictFailure>());
    },
  );
  test(
    'invites store profile and assignments but no password or invite URL',
    () async {
      final invited = await users.inviteUser(
        context: context,
        draft: const StaffDraft(
          email: ' New@Example.test ',
          displayName: 'New Cashier',
          assignments: [
            StaffAssignmentDraft(roleId: 'cashier', branchId: 'second'),
          ],
        ),
      );
      expect(invited.failureOrNull, isNull);
      final account = await (database.select(
        database.appUsers,
      )..where((row) => row.id.equals(invited.valueOrNull!))).getSingle();
      expect(account.email, 'new@example.test');
      expect(account.status, 'invited');
      expect(account.firebaseUid, isNull);
      final queued = await database
          .select(database.syncOutboxEntries)
          .getSingle();
      expect(queued.payloadJson.toLowerCase(), isNot(contains('password')));
      expect(queued.payloadJson.toLowerCase(), isNot(contains('https://')));
      expect(
        (await users.watchUsers(context: context).first)
            .singleWhere((row) => row.id == account.id)
            .assignments,
        hasLength(1),
      );
    },
  );
  test(
    'last-admin role permission removal rolls back permissions and outbox',
    () async {
      final changed = await users.updateRole(
        context: context,
        roleId: 'owner',
        expectedVersion: 0,
        draft: const RoleDraft(
          code: 'owner',
          name: 'Owner',
          permissions: {AppPermission.manageUsers},
        ),
      );
      expect(changed.failureOrNull, isA<ValidationFailure>());
      expect(
        await database.select(database.rolePermissions).get(),
        hasLength(4),
      );
      expect(await database.select(database.syncOutboxEntries).get(), isEmpty);
      expect(
        (await (database.select(
          database.roles,
        )..where((row) => row.id.equals('owner'))).getSingle()).version,
        0,
      );
    },
  );
  test(
    'self-lockout is blocked even with a second full administrator',
    () async {
      await staff('other-admin');
      final changed = await users.replaceAssignments(
        context: context,
        userId: 'admin',
        assignments: const [
          StaffAssignmentDraft(roleId: 'cashier', branchId: 'main'),
        ],
      );
      expect(changed.failureOrNull?.message, contains('your own'));
      expect(
        (await (database.select(
          database.userRoleAssignments,
        )..where((row) => row.userId.equals('admin'))).getSingle()).revokedAt,
        isNull,
      );
      expect(await database.select(database.syncOutboxEntries).get(), isEmpty);
    },
  );
  test(
    'assignment changes increment user version and reject a foreign user',
    () async {
      await staff('cashier-user', role: 'cashier', branch: 'main');
      final changed = await users.replaceAssignments(
        context: context,
        userId: 'cashier-user',
        assignments: const [
          StaffAssignmentDraft(roleId: 'cashier', branchId: 'second'),
        ],
      );
      expect(changed.failureOrNull, isNull);
      expect(
        (await (database.select(
          database.appUsers,
        )..where((row) => row.id.equals('cashier-user'))).getSingle()).version,
        1,
      );
      final command = await database
          .select(database.syncOutboxEntries)
          .getSingle();
      expect(jsonDecode(command.payloadJson)['expectedVersion'], 0);
      final foreign = await users.replaceAssignments(
        context: context,
        userId: 'not-in-org',
        assignments: const [
          StaffAssignmentDraft(roleId: 'cashier', branchId: 'main'),
        ],
      );
      expect(foreign.failureOrNull, isA<AuthorizationFailure>());
      expect(
        await database.select(database.syncOutboxEntries).get(),
        hasLength(1),
      );
    },
  );
  test(
    'disablement revokes assignments without deleting historical references',
    () async {
      await staff('cashier-user', role: 'cashier', branch: 'main');
      final changed = await users.setUserStatus(
        context: context,
        userId: 'cashier-user',
        status: UserAccountStatus.disabled,
        expectedVersion: 0,
      );
      expect(changed.failureOrNull, isNull);
      expect(
        (await (database.select(
          database.appUsers,
        )..where((row) => row.id.equals('cashier-user'))).getSingle()).status,
        'disabled',
      );
      expect(
        (await (database.select(
              database.userRoleAssignments,
            )..where((row) => row.userId.equals('cashier-user'))).getSingle())
            .revokedAt,
        isNotNull,
      );
      expect(
        await database.select(database.localAuditLogs).get(),
        hasLength(1),
      );
    },
  );
}

class _Ids implements IdGenerator {
  int sequence = 0;
  @override
  String newId() => 'admin-test-id-${sequence++}';
}
