import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/models/outbox_command.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/features/auth/data/datasources/access_local_data_source.dart';
import 'package:jce_pos/features/auth/data/repositories/drift_active_context_repository.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/auth/domain/usecases/require_permission_usecase.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart' as model;
import 'package:jce_pos/shared/models/branch.dart' as model;
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/organization.dart' as model;
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  late AppDatabase database;
  late DriftAccessLocalDataSource localDataSource;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    localDataSource = DriftAccessLocalDataSource(database);
  });

  tearDown(() => database.close());

  test(
    'cached access excludes directory-only branches until access refresh',
    () async {
      await localDataSource.replaceProfile(_profile(includeBranchB: false));
      final now = DateTime.utc(2026, 9, 6);
      await database
          .into(database.branches)
          .insert(
            BranchesCompanion.insert(
              id: 'branch-b',
              organizationId: 'org-a',
              code: 'B',
              name: 'Branch B',
              createdAt: now,
              updatedAt: now,
            ),
          );
      var cached = await localDataSource.findByFirebaseUid('firebase-user');
      expect(cached!.organizations.single.branchById('branch-b'), isNull);
      await localDataSource.replaceProfile(_profile());
      cached = await localDataSource.findByFirebaseUid('firebase-user');
      expect(cached!.organizations.single.branchById('branch-b'), isNotNull);
      await localDataSource.replaceProfile(_profile(includeBranchB: false));
      cached = await localDataSource.findByFirebaseUid('firebase-user');
      expect(cached!.organizations.single.branchById('branch-b'), isNull);
      expect(await database.select(database.branches).get(), hasLength(2));
    },
  );

  test(
    'refresh and revocation preserve identity and historical assignment rows',
    () async {
      await localDataSource.replaceProfile(_profile());
      final assignments = await database
          .select(database.userRoleAssignments)
          .get();
      await localDataSource.replaceProfile(_profile());
      expect(
        await database.select(database.userRoleAssignments).get(),
        hasLength(assignments.length),
      );
      await localDataSource.clearProfile('firebase-user');
      expect(await localDataSource.findByFirebaseUid('firebase-user'), isNull);
      expect(await database.select(database.appUsers).get(), hasLength(1));
      expect(
        await database.select(database.userRoleAssignments).get(),
        hasLength(assignments.length),
      );
      await localDataSource.replaceProfile(_profile());
      expect(
        await localDataSource.findByFirebaseUid('firebase-user'),
        isNotNull,
      );
    },
  );

  test(
    'refresh does not overwrite a pending branch operational profile',
    () async {
      await localDataSource.replaceProfile(_profile());
      await (database.update(
        database.branches,
      )..where((row) => row.id.equals('branch-a'))).write(
        const BranchesCompanion(
          name: Value('Offline name'),
          addressLineOne: Value('1 Main Street'),
          receiptDisplayName: Value('Receipt name'),
          version: Value(1),
        ),
      );
      await database.outboxDao.enqueue(
        OutboxCommand(
          operationId: 'pending',
          commandType: 'branch.update',
          aggregateType: 'branch',
          aggregateId: 'branch-a',
          organizationId: 'org-a',
          payload: const {},
          createdAt: DateTime.utc(2026),
        ),
      );
      await localDataSource.replaceProfile(_profile());
      final cached = await localDataSource.findByFirebaseUid('firebase-user');
      final branch = cached!.organizations.single
          .branchById('branch-a')!
          .branch;
      expect(branch.name, 'Offline name');
      expect(branch.receiptDisplayName, 'Receipt name');
      expect(branch.addressLineOne, '1 Main Street');
    },
  );

  test('cached access observes local branch profile changes', () async {
    await localDataSource.replaceProfile(_profile());
    final updates = localDataSource.watchBranchProfilesByFirebaseUid(
      'firebase-user',
    );
    final changed = updates.firstWhere(
      (profile) =>
          profile?.organizations.single.branchById('branch-a')?.branch.name ==
          'Sweetland Branch',
    );

    await (database.update(database.branches)
          ..where((row) => row.id.equals('branch-a')))
        .write(const BranchesCompanion(name: Value('Sweetland Branch')));

    final profile = await changed.timeout(const Duration(seconds: 2));
    expect(
      profile!.organizations.single.branchById('branch-a')!.branch.name,
      'Sweetland Branch',
    );
  });

  test(
    'unaccepted branch creation remains unavailable even in a stale profile',
    () async {
      await localDataSource.replaceProfile(_profile());
      await database.outboxDao.enqueue(
        OutboxCommand(
          operationId: 'create',
          commandType: 'branch.create',
          aggregateType: 'branch',
          aggregateId: 'branch-b',
          organizationId: 'org-a',
          payload: const {},
          createdAt: DateTime.utc(2026),
        ),
      );
      final cached = await localDataSource.findByFirebaseUid('firebase-user');
      expect(cached!.organizations.single.branchById('branch-b'), isNull);
    },
  );

  test(
    'access profile round-trips through Drift with role permissions',
    () async {
      await localDataSource.replaceProfile(_profile());

      final restored = await localDataSource.findByFirebaseUid('firebase-user');
      final organization = restored!.organizations.single;

      expect(organization.branches, hasLength(2));
      expect(
        organization.permissionsFor('branch-a'),
        containsAll({AppPermission.viewDashboard, AppPermission.processSales}),
      );
      expect(
        organization.permissionsFor('branch-b'),
        contains(AppPermission.viewDashboard),
      );
      expect(
        organization.permissionsFor('branch-b'),
        isNot(contains(AppPermission.processSales)),
      );
    },
  );

  test(
    'last active branch is restored only while it remains assigned',
    () async {
      final repository = DriftActiveContextRepository(
        metadataDao: database.metadataDao,
        clock: FixedAppClock(DateTime.utc(2026, 6, 25)),
      );
      final profile = _profile();
      final branchB = AuthSession(
        user: profile,
        activeOrganizationId: 'org-a',
        activeBranchId: 'branch-b',
      );
      await repository.save(branchB);

      expect((await repository.restore(profile)).activeBranchId, 'branch-b');

      final profileWithoutBranchB = _profile(includeBranchB: false);
      expect(
        (await repository.restore(profileWithoutBranchB)).activeBranchId,
        'branch-a',
      );
    },
  );

  test('unassigned branches and mismatched request contexts are denied', () {
    final session = AuthSession(
      user: _profile(),
      activeOrganizationId: 'org-a',
      activeBranchId: 'branch-a',
    );

    expect(
      () => session.switchTo(organizationId: 'org-a', branchId: 'not-assigned'),
      throwsArgumentError,
    );

    final result = const RequirePermissionUseCase().call(
      session: session,
      permission: AppPermission.processSales,
      organizationId: 'org-a',
      branchId: 'branch-b',
    );
    expect(result.failureOrNull, isA<AuthorizationFailure>());
  });

  test('permission checks use database codes instead of role names', () {
    expect(
      AppPermission.fromCode('inventory.manage'),
      AppPermission.manageInventory,
    );
    expect(AppPermission.fromCode('unknown.permission'), isNull);

    final session = AuthSession(
      user: _profile(),
      activeOrganizationId: 'org-a',
      activeBranchId: 'branch-a',
    );
    final result = const RequirePermissionUseCase().call(
      session: session,
      permission: AppPermission.processSales,
      organizationId: 'org-a',
      branchId: 'branch-a',
    );
    expect(result.isSuccess, isTrue);
  });
}

model.AppUser _profile({bool includeBranchB = true}) {
  const dashboardRole = AccessRole(
    id: 'role-dashboard',
    code: 'dashboard_reader',
    name: 'Dashboard Reader',
    permissions: {AppPermission.viewDashboard},
  );
  const cashierRole = AccessRole(
    id: 'role-cashier',
    code: 'cashier',
    name: 'Cashier',
    permissions: {AppPermission.processSales},
  );
  return model.AppUser(
    firebaseUid: 'firebase-user',
    email: 'user@jce.test',
    displayName: 'JCE User',
    organizations: [
      OrganizationAccess(
        appUserId: 'app-user-a',
        organization: const model.Organization(
          id: 'org-a',
          code: 'JCE',
          name: 'JCE',
          timezone: 'Asia/Manila',
        ),
        status: UserAccountStatus.active,
        organizationRoles: const [dashboardRole],
        branches: [
          const BranchAccess(
            branch: model.Branch(
              id: 'branch-a',
              organizationId: 'org-a',
              code: 'A',
              name: 'Branch A',
              timezone: 'Asia/Manila',
            ),
            roles: [cashierRole],
          ),
          if (includeBranchB)
            const BranchAccess(
              branch: model.Branch(
                id: 'branch-b',
                organizationId: 'org-a',
                code: 'B',
                name: 'Branch B',
                timezone: 'Asia/Manila',
              ),
              roles: [],
            ),
        ],
      ),
    ],
  );
}
