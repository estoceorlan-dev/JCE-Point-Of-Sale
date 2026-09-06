import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../entities/staff_account.dart';
import '../repositories/users_repository.dart';

class ManageRolesUseCase {
  const ManageRolesUseCase(this._repository);

  final UsersRepository _repository;

  Future<Result<String, Failure>> create({
    required AuthSession? session,
    required RoleDraft draft,
  }) {
    final context = _context(session);
    return context.fold(
      onSuccess: (value) =>
          _repository.createRole(context: value, draft: draft),
      onFailure: (failure) => Future.value(Result.failure(failure)),
    );
  }

  Future<Result<void, Failure>> update({
    required AuthSession? session,
    required RoleDefinition role,
    required RoleDraft draft,
  }) {
    final context = _context(session);
    return context.fold(
      onSuccess: (value) => _repository.updateRole(
        context: value,
        roleId: role.id,
        draft: draft,
        expectedVersion: role.version,
      ),
      onFailure: (failure) => Future.value(Result.failure(failure)),
    );
  }

  Future<Result<void, Failure>> setArchived({
    required AuthSession? session,
    required RoleDefinition role,
    required bool archived,
  }) {
    final context = _context(session);
    return context.fold(
      onSuccess: (value) => _repository.setRoleArchived(
        context: value,
        roleId: role.id,
        archived: archived,
        expectedVersion: role.version,
      ),
      onFailure: (failure) => Future.value(Result.failure(failure)),
    );
  }

  Result<BusinessContext, Failure> _context(AuthSession? session) {
    if (session == null) {
      return const Result.failure(
        AuthorizationFailure('Authentication is required.'),
      );
    }
    if (!session.canOrganizationWide(AppPermission.manageRoles)) {
      return const Result.failure(
        AuthorizationFailure(
          'An organization-wide roles.manage role is required.',
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
}
