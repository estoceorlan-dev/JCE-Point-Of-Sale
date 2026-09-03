import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/operational_setting.dart';
import '../repositories/settings_repository.dart';

class SaveFeatureFlagUseCase {
  const SaveFeatureFlagUseCase({
    required SettingsRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final SettingsRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required String key,
    required bool isEnabled,
    required SettingScope scope,
  }) {
    if (session == null) {
      return Future.value(
        const Result.failure(
          AuthorizationFailure('Authentication is required.'),
        ),
      );
    }
    final context = BusinessContext(
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
      actorUserId: session.activeOrganization.appUserId,
    );
    final authorization = _requirePermission(
      session: session,
      permission: AppPermission.manageSettings,
      organizationId: context.organizationId,
      branchId: context.branchId,
    );
    if (authorization case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.saveFeatureFlag(
      context: context,
      key: key,
      isEnabled: isEnabled,
      scope: scope,
    );
  }
}
