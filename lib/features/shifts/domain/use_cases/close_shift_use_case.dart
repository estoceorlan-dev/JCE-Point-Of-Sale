import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/cash_shift.dart';
import '../repositories/shift_repository.dart';
import 'shift_use_case_context.dart';

class CloseShiftUseCase {
  const CloseShiftUseCase({
    required ShiftRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final ShiftRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required CloseShiftDraft draft,
    bool approveAsManager = false,
  }) async {
    final context = requireShiftContext(
      session: session,
      requirePermission: _requirePermission,
      permission: AppPermission.processSales,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final businessContext = context.valueOrNull!;
    final shift = await _repository.getShift(
      context: businessContext,
      shiftId: draft.shiftId,
    );
    if (shift == null) {
      return const Result.failure(
        ValidationFailure('The shift was not found.'),
      );
    }
    final needsManager =
        approveAsManager || shift.openedByUserId != businessContext.actorUserId;
    String? approvedByUserId;
    if (needsManager) {
      final approval = requireShiftContext(
        session: session,
        requirePermission: _requirePermission,
        permission: AppPermission.approveShiftDiscrepancies,
      );
      if (approval case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
      approvedByUserId = businessContext.actorUserId;
    }
    return _repository.closeShift(
      context: businessContext,
      draft: draft,
      approvedByUserId: approvedByUserId,
    );
  }
}
