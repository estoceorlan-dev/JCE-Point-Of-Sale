import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../repositories/inventory_repository.dart';
import 'inventory_use_case_context.dart';

class CompleteStockCountUseCase {
  const CompleteStockCountUseCase({
    required InventoryRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final InventoryRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<String?, Failure>> call({
    required AuthSession? session,
    required String stockCountId,
    required int expectedVersion,
    String? operationId,
  }) async {
    final context = requireInventoryContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageInventory,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.completeStockCount(
      context: context.valueOrNull!,
      stockCountId: stockCountId,
      expectedVersion: expectedVersion,
      operationId: operationId,
    );
  }
}
