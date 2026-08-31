import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/stock_transfer.dart';
import '../repositories/transfers_repository.dart';
import 'transfer_use_case_context.dart';

class ConfigureTransferPolicyUseCase {
  const ConfigureTransferPolicyUseCase({
    required TransfersRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final TransfersRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required TransferPolicy policy,
  }) {
    final context = requireTransferContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageSettings,
    );
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.configurePolicy(
      context: context.valueOrNull!,
      policy: policy,
    );
  }
}
