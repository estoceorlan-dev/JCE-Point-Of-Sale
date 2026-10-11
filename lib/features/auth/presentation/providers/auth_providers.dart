import '../../data/repositories/browser_installation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'native_auth_providers.dart';
import '../../data/repositories/node_auth_repository.dart';
import '../../data/repositories/node_device_registration_repository.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/services/audit_log_service.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../data/datasources/access_local_data_source.dart';
import '../../data/repositories/demo_device_registration_repository.dart';
import '../../data/repositories/hardcoded_auth_repository.dart';
import '../../data/repositories/local_auth_audit_repository.dart';
import '../../data/repositories/noop_auth_audit_repository.dart';
import '../../domain/repositories/auth_audit_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/device_registration_repository.dart';
import '../../domain/repositories/operational_access_policy.dart';
import '../../domain/usecases/refresh_access_usecase.dart';
import '../../domain/usecases/require_permission_usecase.dart';
import '../../domain/usecases/select_active_branch_usecase.dart';
import '../../domain/usecases/send_password_reset_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';

final accessLocalDataSourceProvider = Provider<AccessLocalDataSource>((ref) {
  return DriftAccessLocalDataSource(ref.watch(appDatabaseProvider));
});

final operationalAccessPolicyProvider = Provider<OperationalAccessPolicy?>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.enableDemoAuth) return null;
  return ref.watch(nodeActorEvidenceProvider);
});

final deviceRegistrationRepositoryProvider =
    Provider<DeviceRegistrationRepository>((ref) {
      final config = ref.watch(appConfigProvider);
      if (config.enableDemoAuth) {
        return const DemoDeviceRegistrationRepository();
      }
      if (kIsWeb) {
        return BrowserInstallationRepository(ref.watch(metadataDaoProvider));
      }
      return NodeDeviceRegistrationRepository(
        ref.watch(nativeApiSessionRepositoryProvider),
        ref.watch(nativeInstallationStoreProvider),
        ref.watch(metadataDaoProvider),
        defaultTargetPlatform == TargetPlatform.windows ? 'windows' : 'android',
      );
    });

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.enableDemoAuth) {
    final repository = HardcodedAuthRepository(branchId: config.demoBranchId!);
    ref.onDispose(repository.dispose);
    return repository;
  }
  final repository = NodeAuthRepository(
    ref.watch(nativeApiSessionRepositoryProvider),
    ref.watch(deviceRegistrationRepositoryProvider),
    ref.watch(accessLocalDataSourceProvider),
    ref.watch(nodeActorEvidenceProvider),
    ref.watch(offlinePinRepositoryProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final authAuditRepositoryProvider = Provider<AuthAuditRepository>((ref) {
  if (ref.watch(appConfigProvider).enableDemoAuth) {
    return const NoopAuthAuditRepository();
  }
  return LocalAuthAuditRepository(
    auditLogService: ref.watch(auditLogServiceProvider),
    deviceRegistrationRepository: ref.watch(
      deviceRegistrationRepositoryProvider,
    ),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(
    authRepository: ref.watch(authRepositoryProvider),
    auditRepository: ref.watch(authAuditRepositoryProvider),
  );
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(
    authRepository: ref.watch(authRepositoryProvider),
    auditRepository: ref.watch(authAuditRepositoryProvider),
  );
});

final selectActiveBranchUseCaseProvider = Provider<SelectActiveBranchUseCase>((
  ref,
) {
  return SelectActiveBranchUseCase(
    authRepository: ref.watch(authRepositoryProvider),
    auditRepository: ref.watch(authAuditRepositoryProvider),
  );
});

final refreshAccessUseCaseProvider = Provider<RefreshAccessUseCase>((ref) {
  return RefreshAccessUseCase(
    authRepository: ref.watch(authRepositoryProvider),
    auditRepository: ref.watch(authAuditRepositoryProvider),
  );
});

final sendPasswordResetUseCaseProvider = Provider<SendPasswordResetUseCase>((
  ref,
) {
  return SendPasswordResetUseCase(ref.watch(authRepositoryProvider));
});

final requirePermissionUseCaseProvider = Provider<RequirePermissionUseCase>((
  ref,
) {
  return const RequirePermissionUseCase();
});
