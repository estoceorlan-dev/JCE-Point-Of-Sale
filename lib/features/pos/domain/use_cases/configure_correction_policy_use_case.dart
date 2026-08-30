import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/sale_correction.dart';
import '../repositories/sales_repository.dart';
import 'pos_use_case_context.dart';

class ConfigureCorrectionPolicyUseCase {
  const ConfigureCorrectionPolicyUseCase({
    required SalesRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final SalesRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required SaleCorrectionPolicy policy,
  }) async {
    final context = requirePosContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageSettings,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.configureCorrectionPolicy(
      context: context.valueOrNull!,
      policy: policy,
    );
  }
}
