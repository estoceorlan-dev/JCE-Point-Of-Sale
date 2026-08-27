import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../entities/product_draft.dart';
import '../repositories/products_repository.dart';
import 'validate_product_use_case.dart';

class CreateProductUseCase {
  const CreateProductUseCase({
    required ProductsRepository repository,
    required RequirePermissionUseCase requirePermission,
    required ValidateProductUseCase validateProduct,
  }) : _repository = repository,
       _requirePermission = requirePermission,
       _validateProduct = validateProduct;

  final ProductsRepository _repository;
  final RequirePermissionUseCase _requirePermission;
  final ValidateProductUseCase _validateProduct;

  Future<Result<String, Failure>> call({
    required AuthSession? session,
    required ProductDraft draft,
  }) async {
    if (session == null) {
      return const Result.failure(
        AuthorizationFailure('Authentication is required.'),
      );
    }
    final validation = _validateProduct(draft);
    if (validation case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final context = _context(session);
    final authorization = _requirePermission(
      session: session,
      permission: AppPermission.manageProducts,
      organizationId: context.organizationId,
      branchId: context.branchId,
    );
    if (authorization case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.createProduct(
      context: context,
      draft: validation.valueOrNull!,
    );
  }
}

BusinessContext _context(AuthSession session) {
  return BusinessContext(
    organizationId: session.activeOrganizationId,
    branchId: session.activeBranchId,
    actorUserId: session.activeOrganization.appUserId,
  );
}
