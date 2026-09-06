import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../repositories/branches_repository.dart';

class SetBranchArchivedUseCase {
  const SetBranchArchivedUseCase(this._repository);

  final BranchAdministrationRepository _repository;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required String branchId,
    required bool archived,
    required int expectedVersion,
  }) {
    if (session == null) {
      return Future.value(
        const Result.failure(
          AuthorizationFailure('Authentication is required.'),
        ),
      );
    }
    if (!session.canOrganizationWide(AppPermission.manageBranches)) {
      return Future.value(
        const Result.failure(
          AuthorizationFailure(
            'An organization-wide branches.manage role is required.',
          ),
        ),
      );
    }
    return _repository.setBranchArchived(
      context: BusinessContext(
        organizationId: session.activeOrganizationId,
        branchId: session.activeBranchId,
        actorUserId: session.activeOrganization.appUserId,
      ),
      branchId: branchId,
      archived: archived,
      expectedVersion: expectedVersion,
    );
  }
}
