import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/goods_receipt.dart';
import '../entities/purchase_order.dart';
import '../repositories/purchases_repository.dart';
import 'purchase_use_case_context.dart';

class PurchaseOrderWorkflowUseCase {
  const PurchaseOrderWorkflowUseCase({
    required PurchasesRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final PurchasesRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> submit({
    required AuthSession? session,
    required PurchaseOrder order,
  }) => _withContext(
    session,
    AppPermission.createPurchases,
    (context) => _repository.submitPurchaseOrder(
      context: context,
      purchaseOrderId: order.id,
      expectedVersion: order.version,
    ),
  );

  Future<Result<void, Failure>> approve({
    required AuthSession? session,
    required PurchaseOrder order,
  }) => _withContext(
    session,
    AppPermission.approvePurchases,
    (context) => _repository.approvePurchaseOrder(
      context: context,
      purchaseOrderId: order.id,
      expectedVersion: order.version,
    ),
  );

  Future<Result<void, Failure>> cancel({
    required AuthSession? session,
    required PurchaseOrder order,
    required String reason,
  }) => _withContext(
    session,
    AppPermission.createPurchases,
    (context) => _repository.cancelPurchaseOrder(
      context: context,
      purchaseOrderId: order.id,
      expectedVersion: order.version,
      reason: reason,
    ),
  );

  Future<Result<String, Failure>> receive({
    required AuthSession? session,
    required PurchaseOrder order,
    required GoodsReceiptDraft draft,
  }) => _withContext(
    session,
    AppPermission.receivePurchases,
    (context) => _repository.receivePurchaseOrder(
      context: context,
      purchaseOrderId: order.id,
      expectedVersion: order.version,
      draft: draft,
    ),
  );

  Future<Result<T, Failure>> _withContext<T>(
    AuthSession? session,
    AppPermission permission,
    Future<Result<T, Failure>> Function(BusinessContext context) action,
  ) {
    final context = requirePurchaseContext(
      session: session,
      requirePermission: _requirePermission,
      permission: permission,
    );
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return action(context.valueOrNull!);
  }
}
