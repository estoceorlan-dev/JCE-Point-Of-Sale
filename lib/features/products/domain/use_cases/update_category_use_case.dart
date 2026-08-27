import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/catalog_drafts.dart';
import '../repositories/products_repository.dart';

class UpdateCategoryUseCase {
  const UpdateCategoryUseCase({
    required ProductsRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final ProductsRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required String categoryId,
    required String name,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.length < 2 || normalizedName.length > 80) {
      return const Result.failure(
        ValidationFailure(
          'Category name must contain between 2 and 80 characters.',
        ),
      );
    }
    final context = _authorizedContext(session);
    if (context case FailureResult<BusinessContext, Failure>(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.updateCategory(
      context: context.valueOrNull!,
      categoryId: categoryId,
      draft: CategoryDraft(name: normalizedName),
    );
  }

  Result<BusinessContext, Failure> _authorizedContext(AuthSession? session) {
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
    return authorization.map((_) => context);
  }
}
