import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../entities/operational_setting.dart';
import '../repositories/settings_repository.dart';

class SaveOperationalSettingUseCase {
  const SaveOperationalSettingUseCase({
    required SettingsRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final SettingsRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> call({
    required AuthSession? session,
    required SettingScope scope,
    required OperationalSettingKey key,
    required Object? value,
  }) async {
    final context = _authorizedContext(session);
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.saveSetting(
      context: context.valueOrNull!,
      scope: scope,
      key: key,
      value: value,
    );
  }

  Future<Result<void, Failure>> clearBranchOverride({
    required AuthSession? session,
    required OperationalSettingKey key,
  }) async {
    final context = _authorizedContext(session);
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return _repository.clearBranchOverride(
      context: context.valueOrNull!,
      key: key,
    );
  }

  Result<BusinessContext, Failure> _authorizedContext(AuthSession? session) {
    if (session == null) {
      return const Result.failure(
        AuthorizationFailure('Authentication is required.'),
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
      return Result.failure(failure);
    }
    return Result.success(context);
  }
}
