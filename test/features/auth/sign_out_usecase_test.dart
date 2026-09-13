import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/error/failure.dart';
import 'package:jce_pos/core/error/result.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/auth/domain/repositories/auth_audit_repository.dart';
import 'package:jce_pos/features/auth/domain/repositories/auth_repository.dart';
import 'package:jce_pos/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart';
import 'package:jce_pos/shared/models/branch.dart';
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/organization.dart';
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  test('audit failure cannot prevent Firebase sign-out', () async {
    final authRepository = _FakeAuthRepository();
    final useCase = SignOutUseCase(
      authRepository: authRepository,
      auditRepository: const _ThrowingAuditRepository(),
    );

    final result = await useCase.call(_session());

    expect(result.isSuccess, isTrue);
    expect(authRepository.signOutCalls, 1);
  });
}

class _FakeAuthRepository implements AuthRepository {
  int signOutCalls = 0;

  @override
  Future<Result<void, Failure>> signOut() async {
    signOutCalls += 1;
    return const Result<void, Failure>.success(null);
  }

  @override
  Stream<Result<AuthSession?, Failure>> authStateChanges() =>
      const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<Result<AuthSession, Failure>> refreshAccess() =>
      throw UnimplementedError();

  @override
  Future<Result<void, Failure>> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<Result<AuthSession, Failure>> selectActiveBranch({
    required String organizationId,
    required String branchId,
  }) => throw UnimplementedError();

  @override
  Future<Result<AuthSession, Failure>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();
}

class _ThrowingAuditRepository implements AuthAuditRepository {
  const _ThrowingAuditRepository();

  @override
  Future<void> recordLogout(AuthSession session) =>
      throw StateError('Local audit storage is unavailable.');

  @override
  Future<void> recordBranchSwitch({
    required AuthSession previous,
    required AuthSession current,
  }) async {}

  @override
  Future<void> recordLogin(AuthSession session) async {}

  @override
  Future<void> recordLoginFailed(String email, {String? reason}) async {}

  @override
  Future<void> recordRoleChange({
    required AuthSession previous,
    required AuthSession current,
  }) async {}
}

AuthSession _session() {
  const role = AccessRole(
    id: 'admin-role',
    code: 'admin',
    name: 'Administrator',
    permissions: {AppPermission.viewDashboard},
  );
  return AuthSession(
    user: AppUser(
      firebaseUid: 'firebase-admin',
      email: 'admin@jce.test',
      displayName: 'Administrator',
      organizations: [
        OrganizationAccess(
          appUserId: 'admin-user',
          organization: const Organization(
            id: 'organization',
            code: 'JCE',
            name: 'JCE',
            timezone: 'Asia/Manila',
          ),
          status: UserAccountStatus.active,
          organizationRoles: const [role],
          branches: const [
            BranchAccess(
              branch: Branch(
                id: 'branch',
                organizationId: 'organization',
                code: 'MAIN',
                name: 'Main',
                timezone: 'Asia/Manila',
              ),
              roles: [],
            ),
          ],
        ),
      ],
    ),
    activeOrganizationId: 'organization',
    activeBranchId: 'branch',
  );
}
