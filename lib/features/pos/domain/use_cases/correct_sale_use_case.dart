import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/sale_correction.dart';
import '../repositories/sales_repository.dart';
import 'pos_use_case_context.dart';

class CorrectSaleUseCase {
  const CorrectSaleUseCase({
    required SalesRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final SalesRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<SaleCorrectionResult, Failure>> call({
    required AuthSession? session,
    required SaleCorrectionDraft draft,
    bool approveAsManager = false,
  }) async {
    final context = requirePosContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.processSaleReturns,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    String? approvedByUserId;
    if (approveAsManager) {
      final approval = requirePosContext(
        session: session,
        requirePermission: _requirePermission,
        permission: AppPermission.approveSaleCorrections,
      );
      if (approval case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
      approvedByUserId = context.valueOrNull!.actorUserId;
    }
    return _repository.correctSale(
      context: context.valueOrNull!,
      draft: draft,
      approvedByUserId: approvedByUserId,
    );
  }
}
