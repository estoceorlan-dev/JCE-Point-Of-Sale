import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/register_hardware_profile.dart';
import '../repositories/pos_hardware_repository.dart';

class ConfigureRegisterHardwareUseCase {
  const ConfigureRegisterHardwareUseCase({
    required PosHardwareRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final PosHardwareRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required RegisterHardwareProfileDraft draft,
  }) async {
    if (session == null) {
      return const Result.failure(
        AuthorizationFailure('Authentication is required.'),
      );
    }
    final authorization = _requirePermission(
      session: session,
      permission: AppPermission.manageRegisters,
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
    );
    if (authorization case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.configureProfile(
      context: BusinessContext(
        organizationId: session.activeOrganizationId,
        branchId: session.activeBranchId,
        actorUserId: session.activeOrganization.appUserId,
      ),
      draft: draft,
    );
  }
}
