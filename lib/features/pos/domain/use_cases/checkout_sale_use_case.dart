import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/sale.dart';
import '../repositories/sales_repository.dart';
import 'pos_use_case_context.dart';

class CheckoutSaleUseCase {
  const CheckoutSaleUseCase({
    required SalesRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final SalesRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<CheckoutResult, Failure>> call({
    required AuthSession? session,
    required CheckoutDraft draft,
    bool approveDiscountAsManager = false,
  }) async {
    final context = requirePosContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.processSales,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    String? approvedByUserId;
    if (approveDiscountAsManager) {
      final approval = requirePosContext(
        session: session,
        requirePermission: _requirePermission,
        permission: AppPermission.approveSaleDiscounts,
      );
      if (approval case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
      approvedByUserId = context.valueOrNull!.actorUserId;
    }
    return _repository.checkout(
      context: context.valueOrNull!,
      draft: draft,
      discountApprovedByUserId: approvedByUserId,
    );
  }
}
