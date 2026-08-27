import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/register.dart';
import '../repositories/shift_repository.dart';
import 'shift_use_case_context.dart';

class CreateRegisterUseCase {
  const CreateRegisterUseCase({
    required ShiftRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final ShiftRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<String, Failure>> call({
    required AuthSession? session,
    required RegisterDraft draft,
  }) async {
    final context = requireShiftContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.manageRegisters,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.createRegister(
      context: context.valueOrNull!,
      draft: draft,
    );
  }
}
