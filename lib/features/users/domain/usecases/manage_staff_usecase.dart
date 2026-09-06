import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/models/user_account_status.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../entities/staff_account.dart';
import '../repositories/users_repository.dart';

class ManageStaffUseCase {
  const ManageStaffUseCase(this._repository);

  final UsersRepository _repository;

  Future<Result<String, Failure>> invite({
    required AuthSession? session,
    required StaffDraft draft,
  }) {
    final context = _context(session, AppPermission.manageUsers);
    return context.fold(
      onSuccess: (value) =>
          _repository.inviteUser(context: value, draft: draft),
      onFailure: (failure) => Future.value(Result.failure(failure)),
    );
  }

  Future<Result<void, Failure>> update({
    required AuthSession? session,
    required StaffAccount account,
    required String displayName,
    required String email,
  }) {
    final context = _context(session, AppPermission.manageUsers);
    return context.fold(
      onSuccess: (value) => _repository.updateUser(
        context: value,
        userId: account.id,
        displayName: displayName,
        email: email,
        expectedVersion: account.version,
      ),
      onFailure: (failure) => Future.value(Result.failure(failure)),
    );
  }

  Future<Result<void, Failure>> replaceAssignments({
    required AuthSession? session,
    required String userId,
    required List<StaffAssignmentDraft> assignments,
  }) {
    final context = _context(session, AppPermission.manageUsers);
    return context.fold(
      onSuccess: (value) => _repository.replaceAssignments(
        context: value,
        userId: userId,
        assignments: assignments,
      ),
      onFailure: (failure) => Future.value(Result.failure(failure)),
    );
  }

  Future<Result<void, Failure>> setStatus({
    required AuthSession? session,
    required StaffAccount account,
    required UserAccountStatus status,
  }) {
    final context = _context(session, AppPermission.manageUsers);
    return context.fold(
      onSuccess: (value) => _repository.setUserStatus(
        context: value,
        userId: account.id,
        status: status,
        expectedVersion: account.version,
      ),
      onFailure: (failure) => Future.value(Result.failure(failure)),
    );
  }
}

Result<BusinessContext, Failure> _context(
  AuthSession? session,
  AppPermission permission,
) {
  if (session == null) {
    return const Result.failure(
      AuthorizationFailure('Authentication is required.'),
    );
  }
  if (!session.canOrganizationWide(permission)) {
    return Result.failure(
      AuthorizationFailure(
        'An organization-wide ${permission.code} role is required.',
      ),
    );
  }
  return Result.success(
    BusinessContext(
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
      actorUserId: session.activeOrganization.appUserId,
    ),
  );
}
