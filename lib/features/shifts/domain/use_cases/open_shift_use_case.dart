import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/cash_shift.dart';
import '../repositories/shift_repository.dart';
import 'shift_use_case_context.dart';

class OpenShiftUseCase {
  const OpenShiftUseCase({
    required ShiftRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final ShiftRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<String, Failure>> call({
    required AuthSession? session,
    required OpenShiftDraft draft,
  }) async {
    final context = requireShiftContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.processSales,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.openShift(context: context.valueOrNull!, draft: draft);
  }
}
