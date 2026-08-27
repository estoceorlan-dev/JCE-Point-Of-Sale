import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/features/auth/data/datasources/access_local_data_source.dart';
import 'package:jce_pos/features/auth/data/datasources/access_remote_data_source.dart';
import 'package:jce_pos/features/auth/data/repositories/offline_first_access_profile_repository.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart';
import 'package:jce_pos/shared/models/branch.dart';
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/organization.dart';
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  final now = DateTime.utc(2026, 8, 23, 12);

  test('cached access is returned then refreshed access is emitted', () async {
    final local = _FakeAccessLocalDataSource(
      user: _profile(displayName: 'Cached User'),
      verifiedAt: now.subtract(const Duration(minutes: 5)),
    );
    final remoteCompleter = Completer<AppUser?>();
    final repository = OfflineFirstAccessProfileRepository(
      local: local,
      remote: _FakeAccessRemoteDataSource(() => remoteCompleter.future),
      clock: FixedAppClock(now),
      maxOfflineAge: const Duration(hours: 24),
    );
    addTearDown(repository.dispose);
    final eventFuture = repository.events.first;

    final cachedResult = await repository.loadProfile(
      firebaseUid: 'firebase-user',
      email: 'user@jce.test',
    );
    expect(cachedResult.valueOrNull?.displayName, 'Cached User');

    remoteCompleter.complete(_profile(displayName: 'Verified User'));
    final event = await eventFuture;
    expect(event.result.valueOrNull?.displayName, 'Verified User');
    expect(local.user?.displayName, 'Verified User');
    expect(local.verifiedAt, now);
  });

  test('remote rejection clears cached access and emits revocation', () async {
    final local = _FakeAccessLocalDataSource(
      user: _profile(displayName: 'Cached User'),
      verifiedAt: now.subtract(const Duration(minutes: 5)),
    );
    final repository = OfflineFirstAccessProfileRepository(
      local: local,
      remote: _FakeAccessRemoteDataSource(
        () => Future<AppUser?>.error(
          const AccessProfileRejectedException('permission-denied'),
        ),
      ),
      clock: FixedAppClock(now),
      maxOfflineAge: const Duration(hours: 24),
    );
    addTearDown(repository.dispose);
    final eventFuture = repository.events.first;

    final cachedResult = await repository.loadProfile(
      firebaseUid: 'firebase-user',
      email: 'user@jce.test',
    );
    expect(cachedResult.isSuccess, isTrue);

    final event = await eventFuture;
    expect(event.result.failureOrNull, isA<AuthorizationFailure>());
    expect(local.user, isNull);
    expect(local.verifiedAt, isNull);
  });

  test('expired cached access cannot mask an unavailable server', () async {
    final local = _FakeAccessLocalDataSource(
      user: _profile(displayName: 'Expired User'),
      verifiedAt: now.subtract(const Duration(hours: 25)),
    );
    final repository = OfflineFirstAccessProfileRepository(
      local: local,
      remote: _FakeAccessRemoteDataSource(
        () => Future<AppUser?>.error(
          const AccessProfileUnavailableException('unavailable'),
        ),
      ),
      clock: FixedAppClock(now),
      maxOfflineAge: const Duration(hours: 24),
    );
    addTearDown(repository.dispose);

    final result = await repository.loadProfile(
      firebaseUid: 'firebase-user',
      email: 'user@jce.test',
    );

    expect(result.failureOrNull, isA<NetworkFailure>());
  });
}

class _FakeAccessLocalDataSource implements AccessLocalDataSource {
  _FakeAccessLocalDataSource({this.user, this.verifiedAt});

  AppUser? user;
  DateTime? verifiedAt;

  @override
  Future<void> clearProfile(String firebaseUid) async {
    user = null;
    verifiedAt = null;
  }

  @override
  Future<AppUser?> findByFirebaseUid(String firebaseUid) async => user;

  @override
  Future<DateTime?> lastVerifiedAt(String firebaseUid) async => verifiedAt;

  @override
  Future<void> recordVerifiedAt(String firebaseUid, DateTime verifiedAt) async {
    this.verifiedAt = verifiedAt;
  }

  @override
  Future<void> replaceProfile(AppUser user) async {
    this.user = user;
  }
}

class _FakeAccessRemoteDataSource implements AccessRemoteDataSource {
  const _FakeAccessRemoteDataSource(this.fetch);

  final Future<AppUser?> Function() fetch;

  @override
  Future<AppUser?> fetchCurrentProfile({
    required String firebaseUid,
    required String email,
  }) {
    return fetch();
  }
}

AppUser _profile({required String displayName}) {
  const role = AccessRole(
    id: 'role',
    code: 'dashboard',
    name: 'Dashboard',
    permissions: {AppPermission.viewDashboard},
  );
  return AppUser(
    firebaseUid: 'firebase-user',
    email: 'user@jce.test',
    displayName: displayName,
    organizations: const [
      OrganizationAccess(
        appUserId: 'app-user',
        organization: Organization(
          id: 'org',
          code: 'ORG',
          name: 'Organization',
          timezone: 'Asia/Manila',
        ),
        status: UserAccountStatus.active,
        organizationRoles: [],
        branches: [
          BranchAccess(
            branch: Branch(
              id: 'branch',
              organizationId: 'org',
              code: 'MAIN',
              name: 'Main',
              timezone: 'Asia/Manila',
            ),
            roles: [role],
          ),
        ],
      ),
    ],
  );
}
