import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/product_draft.dart';
import '../repositories/products_repository.dart';
import 'validate_product_use_case.dart';

class UpdateProductUseCase {
  const UpdateProductUseCase({
    required ProductsRepository repository,
    required RequirePermissionUseCase requirePermission,
    required ValidateProductUseCase validateProduct,
  }) : _repository = repository,
       _requirePermission = requirePermission,
       _validateProduct = validateProduct;

  final ProductsRepository _repository;
  final RequirePermissionUseCase _requirePermission;
  final ValidateProductUseCase _validateProduct;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required String productId,
    required ProductDraft draft,
  }) async {
    if (session == null) {
      return const Result.failure(
        AuthorizationFailure('Authentication is required.'),
      );
    }
    if (productId.trim().isEmpty) {
      return const Result.failure(ValidationFailure('Product ID is required.'));
    }
    final validation = _validateProduct(draft);
    if (validation case FailureResult(:final failure)) {
      return Result.failure(failure);
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
    return _repository.updateProduct(
      context: context,
      productId: productId,
      draft: validation.valueOrNull!,
    );
  }
}
