import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/stock_location.dart';
import '../repositories/inventory_repository.dart';
import 'inventory_use_case_context.dart';

class UpdateStockLocationUseCase {
  const UpdateStockLocationUseCase({
    required this.repository,
    required this.requirePermission,
  });
  final InventoryRepository repository;
  final RequirePermissionUseCase requirePermission;
  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required StockLocation location,
    required StockLocationDraft draft,
  }) async {
    final context = requireInventoryContext(
      session: session,
      requirePermission: requirePermission,
      permission: AppPermission.manageInventory,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return repository.updateStockLocation(
      context: context.valueOrNull!,
      locationId: location.id,
      draft: draft,
      expectedVersion: location.version,
    );
  }
}

class SetStockLocationArchivedUseCase {
  const SetStockLocationArchivedUseCase({
    required this.repository,
    required this.requirePermission,
  });
  final InventoryRepository repository;
  final RequirePermissionUseCase requirePermission;
  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required StockLocation location,
    required bool archived,
  }) async {
    final context = requireInventoryContext(
      session: session,
      requirePermission: requirePermission,
      permission: AppPermission.manageInventory,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return repository.setStockLocationArchived(
      context: context.valueOrNull!,
      locationId: location.id,
      archived: archived,
      expectedVersion: location.version,
    );
  }
}
