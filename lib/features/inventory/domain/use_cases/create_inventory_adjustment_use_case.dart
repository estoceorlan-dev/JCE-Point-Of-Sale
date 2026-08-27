import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/inventory_adjustment.dart';
import '../repositories/inventory_repository.dart';
import 'inventory_use_case_context.dart';

class CreateInventoryAdjustmentUseCase {
  const CreateInventoryAdjustmentUseCase({
    required InventoryRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final InventoryRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<String, Failure>> call({
    required AuthSession? session,
    required InventoryAdjustmentDraft draft,
    bool approveAsManager = false,
  }) async {
    final context = requireInventoryContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageInventory,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    String? approvedByUserId;
    if (approveAsManager) {
      final approval = requireInventoryContext(
        session: session,
        requirePermission: _requirePermission,
        permission: AppPermission.approveInventoryAdjustments,
      );
      if (approval case FailureResult(:final failure)) {
        return Result.failure(
          AuthorizationFailure(
            'Manager approval permission is required for this adjustment.',
            code: 'inventory-approval-required',
            cause: failure,
          ),
        );
      }
      approvedByUserId = approval.valueOrNull!.actorUserId;
    }
    return _repository.createAdjustment(
      context: context.valueOrNull!,
      draft: draft,
      approvedByUserId: approvedByUserId,
    );
  }
}
