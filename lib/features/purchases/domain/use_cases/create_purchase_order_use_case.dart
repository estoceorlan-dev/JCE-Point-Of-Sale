import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/purchase_order.dart';
import '../repositories/purchases_repository.dart';
import 'purchase_use_case_context.dart';

class CreatePurchaseOrderUseCase {
  const CreatePurchaseOrderUseCase({
    required PurchasesRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final PurchasesRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<String, Failure>> call({
    required AuthSession? session,
    required PurchaseOrderDraft draft,
  }) {
    final context = requirePurchaseContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.createPurchases,
    );
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.createPurchaseOrder(
      context: context.valueOrNull!,
      draft: draft,
    );
  }
}
