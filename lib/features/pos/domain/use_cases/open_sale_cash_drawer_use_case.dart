import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../../../hardware/domain/repositories/pos_hardware_repository.dart';
import '../../../hardware/domain/services/cash_drawer.dart';
import '../entities/payment.dart';
import '../entities/sale.dart';
import '../entities/sale_status.dart';

class OpenSaleCashDrawerUseCase {
  const OpenSaleCashDrawerUseCase({
    required PosHardwareRepository repository,
    required CashDrawer cashDrawer,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _cashDrawer = cashDrawer,
       _requirePermission = requirePermission;

  final PosHardwareRepository _repository;
  final CashDrawer _cashDrawer;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<bool, Failure>> call({
    required AuthSession? session,
    required SaleRecord sale,
  }) async {
    if (session == null) {
      return const Result.failure(
        AuthorizationFailure('Authentication is required.'),
      );
    }
    if (sale.status != SaleStatus.completed ||
        sale.branchId != session.activeBranchId ||
        !sale.payments.any(
          (payment) =>
              payment.method == SalePaymentMethod.cash &&
              payment.appliedAmountMinor > 0,
        )) {
      return const Result.failure(
        AuthorizationFailure(
          'The cash drawer may open only for a completed cash payment in the active branch.',
        ),
      );
    }
    final authorization = _requirePermission(
      session: session,
      permission: AppPermission.processSales,
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
    );
    if (authorization case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final profile = await _repository.getProfile(
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
      registerId: sale.registerId,
    );
    if (profile == null || !profile.cashDrawerEnabled) {
      return const Result.success(false);
    }
    final result = await _cashDrawer.open(profile: profile);
    return result.map((_) => true);
  }
}
