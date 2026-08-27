import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../repositories/products_repository.dart';

class SetUnitArchivedUseCase {
  const SetUnitArchivedUseCase({
    required ProductsRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final ProductsRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required String unitId,
    required bool archived,
  }) async {
    if (session == null) {
      return const Result.failure(
        AuthorizationFailure('Authentication is required.'),
      );
    }
    final context = BusinessContext(
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
      actorUserId: session.activeOrganization.appUserId,
    );
    final authorization = _requirePermission(
      session: session,
      permission: AppPermission.manageProducts,
      organizationId: context.organizationId,
      branchId: context.branchId,
    );
    if (authorization case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.setUnitArchived(
      context: context,
      unitId: unitId,
      archived: archived,
    );
  }
}
