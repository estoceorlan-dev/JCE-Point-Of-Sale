import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/cash_shift.dart';
import '../repositories/shift_repository.dart';
import 'shift_use_case_context.dart';

class ConfigureShiftPolicyUseCase {
  const ConfigureShiftPolicyUseCase({
    required ShiftRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final ShiftRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required ShiftPolicy policy,
  }) async {
    final context = requireShiftContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageRegisters,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.configurePolicy(
      context: context.valueOrNull!,
      policy: policy,
    );
  }
}
