import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/product_price.dart';
import '../repositories/products_repository.dart';

class AddProductPriceUseCase {
  const AddProductPriceUseCase({
    required ProductsRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final ProductsRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<String, Failure>> call({
    required AuthSession? session,
    required String productId,
    required ProductPriceDraft draft,
  }) async {
    if (draft.unitPriceMinor < 0) {
      return const Result.failure(
        ValidationFailure('Unit price cannot be negative.'),
      );
    }
    if (draft.scope == PriceScope.organization && draft.branchId != null) {
      return const Result.failure(
        ValidationFailure('Organization pricing cannot target a branch.'),
      );
    }
    if (draft.scope == PriceScope.branch && draft.branchId == null) {
      return const Result.failure(
        ValidationFailure('Branch pricing requires a branch.'),
      );
    }
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
    return _repository.addProductPrice(
      context: context,
      productId: productId,
      draft: draft,
    );
  }
}
