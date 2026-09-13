import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/register_claim.dart';
import '../repositories/register_claim_repository.dart';
import 'shift_use_case_context.dart';

class ClaimRegisterUseCase {
  const ClaimRegisterUseCase({
    required RegisterClaimRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final RegisterClaimRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<RegisterClaim, Failure>> call({
    required AuthSession? session,
    required String registerId,
    required String deviceId,
    required int expectedVersion,
  }) async {
    final context = requireShiftContext(
      session: session,
      requirePermission: _requirePermission,
      permission: session?.can(AppPermission.manageRegisters) == true
          ? AppPermission.manageRegisters
          : AppPermission.claimRegisters,
    );
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.claim(
      context: context.valueOrNull!,
      registerId: registerId,
      deviceId: deviceId,
      expectedVersion: expectedVersion,
    );
  }
}
