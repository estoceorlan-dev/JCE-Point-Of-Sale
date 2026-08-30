import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/access_role.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/branch.dart';
import '../../../../shared/models/branch_access.dart';
import '../../../../shared/models/organization.dart';
import '../../../../shared/models/organization_access.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/models/user_account_status.dart';
import '../../../../shared/models/user_role.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

class HardcodedAuthRepository implements AuthRepository {
  HardcodedAuthRepository({required String branchId})
    : _users = _createUsers(branchId);

  static const _demoPassword = 'password123';

  final Map<String, AuthSession> _users;
  final StreamController<Result<AuthSession?, Failure>> _changes =
      StreamController<Result<AuthSession?, Failure>>.broadcast();

  AuthSession? _currentSession;

  static Map<String, AuthSession> _createUsers(String branchId) {
    return {
      for (final entry in const <(String, String, UserRole)>[
        ('owner@jce.test', 'JCE Owner', UserRole.owner),
        ('admin@jce.test', 'System Admin', UserRole.admin),
        ('manager@jce.test', 'Branch Manager', UserRole.manager),
        ('cashier@jce.test', 'Cashier Staff', UserRole.cashier),
        ('inventory@jce.test', 'Inventory Clerk', UserRole.inventoryClerk),
        ('auditor@jce.test', 'Audit User', UserRole.auditor),
      ])
        entry.$1: _createSession(
          email: entry.$1,
          displayName: entry.$2,
          role: entry.$3,
          branchId: branchId,
        ),
    };
  }

  static AuthSession _createSession({
    required String email,
    required String displayName,
    required UserRole role,
    required String branchId,
  }) {
    const organizationId = 'demo-organization';
    final accessRole = AccessRole(
      id: 'demo-role-${role.name}',
      code: role.name,
      name: role.label,
      permissions: _demoPermissions(role),
    );
    final organizationAccess = OrganizationAccess(
      appUserId: 'demo-user-${role.name}',
      organization: const Organization(
        id: organizationId,
        code: 'DEMO',
        name: 'JCE Demo Organization',
        timezone: 'Asia/Manila',
      ),
      status: UserAccountStatus.active,
      organizationRoles: const [],
      branches: [
        BranchAccess(
          branch: Branch(
            id: branchId,
            organizationId: organizationId,
            code: 'DEMO',
            name: 'Demo Branch',
            timezone: 'Asia/Manila',
          ),
          roles: [accessRole],
        ),
      ],
    );
    return AuthSession(
      user: AppUser(
        firebaseUid: 'demo-${role.name}',
        email: email,
        displayName: displayName,
        organizations: [organizationAccess],
      ),
      activeOrganizationId: organizationId,
      activeBranchId: branchId,
    );
  }

  @override
  Stream<Result<AuthSession?, Failure>> authStateChanges() async* {
    yield Result<AuthSession?, Failure>.success(_currentSession);
    yield* _changes.stream;
  }

  @override
  Future<Result<AuthSession, Failure>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final session = _users[normalizedEmail];
    if (session == null || password != _demoPassword) {
      return const Result<AuthSession, Failure>.failure(
        AuthenticationFailure(
          'Email or password is incorrect.',
          code: 'invalid-credential',
        ),
      );
    }
    _currentSession = session;
    _changes.add(Result<AuthSession?, Failure>.success(session));
    return Result<AuthSession, Failure>.success(session);
  }

  @override
  Future<Result<AuthSession, Failure>> selectActiveBranch({
    required String organizationId,
    required String branchId,
  }) async {
    final current = _currentSession;
    if (current == null) {
      return const Result<AuthSession, Failure>.failure(
        AuthenticationFailure('Authentication is required.'),
      );
    }
    try {
      final updated = current.switchTo(
        organizationId: organizationId,
        branchId: branchId,
      );
      _currentSession = updated;
      _changes.add(Result<AuthSession?, Failure>.success(updated));
      return Result<AuthSession, Failure>.success(updated);
    } on ArgumentError catch (error, stackTrace) {
      return Result<AuthSession, Failure>.failure(
        AuthorizationFailure(
          'The selected branch is not assigned to this account.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<AuthSession, Failure>> refreshAccess() async {
    final current = _currentSession;
    if (current == null) {
      return const Result<AuthSession, Failure>.failure(
        AuthenticationFailure('Authentication is required.'),
      );
    }
    return Result<AuthSession, Failure>.success(current);
  }

  @override
  Future<Result<void, Failure>> sendPasswordResetEmail(String email) async {
    return const Result<void, Failure>.success(null);
  }

  @override
  Future<Result<void, Failure>> signOut() async {
    _currentSession = null;
    _changes.add(const Result<AuthSession?, Failure>.success(null));
    return const Result<void, Failure>.success(null);
  }

  @override
  Future<void> dispose() => _changes.close();

  static Set<AppPermission> _demoPermissions(UserRole role) {
    return switch (role) {
      UserRole.owner || UserRole.admin => {...AppPermission.values},
      UserRole.manager => {
        AppPermission.viewDashboard,
        AppPermission.processSales,
        AppPermission.processSaleReturns,
        AppPermission.approveSaleCorrections,
        AppPermission.approveSaleDiscounts,
        AppPermission.manageProducts,
        AppPermission.manageInventory,
        AppPermission.manageRegisters,
        AppPermission.approveShiftDiscrepancies,
        AppPermission.approveTransfers,
        AppPermission.createPurchases,
        AppPermission.viewReports,
        AppPermission.viewAuditLogs,
      },
      UserRole.cashier => {
        AppPermission.viewDashboard,
        AppPermission.processSales,
        AppPermission.processSaleReturns,
      },
      UserRole.inventoryClerk => {
        AppPermission.viewDashboard,
        AppPermission.manageProducts,
        AppPermission.manageInventory,
        AppPermission.approveTransfers,
        AppPermission.createPurchases,
      },
      UserRole.auditor => {
        AppPermission.viewDashboard,
        AppPermission.viewReports,
        AppPermission.viewAuditLogs,
      },
    };
  }
}
