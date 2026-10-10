import '../../data/repositories/browser_installation_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'native_auth_providers.dart';
import '../../data/repositories/node_auth_repository.dart';
import '../../data/repositories/node_device_registration_repository.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/remote/firebase_functions_provider.dart';
import '../../../../core/services/audit_log_service.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../data/datasources/access_local_data_source.dart';
import '../../data/datasources/access_remote_data_source.dart';
import '../../data/repositories/cloud_functions_device_registration_repository.dart';
import '../../data/repositories/cached_operational_access_policy.dart';
import '../../data/repositories/demo_device_registration_repository.dart';
import '../../data/repositories/drift_active_context_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../data/repositories/hardcoded_auth_repository.dart';
import '../../data/repositories/local_auth_audit_repository.dart';
import '../../data/repositories/noop_auth_audit_repository.dart';
import '../../data/repositories/offline_first_access_profile_repository.dart';
import '../../domain/repositories/access_profile_repository.dart';
import '../../domain/repositories/active_context_repository.dart';
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

final firebaseAuthProvider = Provider<firebase.FirebaseAuth>((ref) {
  return firebase.FirebaseAuth.instance;
});

final accessLocalDataSourceProvider = Provider<AccessLocalDataSource>((ref) {
  return DriftAccessLocalDataSource(ref.watch(appDatabaseProvider));
});

final accessRemoteDataSourceProvider = Provider<AccessRemoteDataSource>((ref) {
  final config = ref.watch(appConfigProvider);
  return CloudFunctionsAccessRemoteDataSource(
    functions: ref.watch(firebaseFunctionsProvider),
    functionName: config.accessProfileFunctionName,
    acceptInvitationFunctionName: config.acceptStaffInviteFunctionName,
  );
});

final accessProfileRepositoryProvider = Provider<AccessProfileRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  final repository = OfflineFirstAccessProfileRepository(
    local: ref.watch(accessLocalDataSourceProvider),
    remote: ref.watch(accessRemoteDataSourceProvider),
    clock: ref.watch(appClockProvider),
    maxOfflineAge: config.maxOfflineAccessAge,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final operationalAccessPolicyProvider = Provider<OperationalAccessPolicy?>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.enableDemoAuth) return null;
  if (config.useNodeBackend) return ref.watch(nodeActorEvidenceProvider);
  return CachedOperationalAccessPolicy(
    metadataDao: ref.watch(metadataDaoProvider),
    clock: ref.watch(appClockProvider),
    maxOfflineAge: config.maxOfflineAccessAge,
  );
});

final activeContextRepositoryProvider = Provider<ActiveContextRepository>((
  ref,
) {
  return DriftActiveContextRepository(
    metadataDao: ref.watch(metadataDaoProvider),
    clock: ref.watch(appClockProvider),
  );
});

final deviceRegistrationRepositoryProvider =
    Provider<DeviceRegistrationRepository>((ref) {
      final config = ref.watch(appConfigProvider);
      if (config.enableDemoAuth) {
        return const DemoDeviceRegistrationRepository();
      }
      if (config.useNodeBackend && kIsWeb) {
        return BrowserInstallationRepository(ref.watch(metadataDaoProvider));
      }
      if (config.useNodeBackend) {
        return NodeDeviceRegistrationRepository(
          ref.watch(nativeApiSessionRepositoryProvider),
          ref.watch(nativeInstallationStoreProvider),
          ref.watch(metadataDaoProvider),
          defaultTargetPlatform == TargetPlatform.windows
              ? 'windows'
              : 'android',
        );
      }
      return CloudFunctionsDeviceRegistrationRepository(
        functions: ref.watch(firebaseFunctionsProvider),
        functionName: config.deviceRegistrationFunctionName,
        metadataDao: ref.watch(metadataDaoProvider),
        outboxDao: ref.watch(outboxDaoProvider),
        idGenerator: ref.watch(idGeneratorProvider),
        clock: ref.watch(appClockProvider),
      );
    });

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.enableDemoAuth) {
    final repository = HardcodedAuthRepository(branchId: config.demoBranchId!);
    ref.onDispose(repository.dispose);
    return repository;
  }
  if (config.useNodeBackend) {
    final repository = NodeAuthRepository(
      ref.watch(nativeApiSessionRepositoryProvider),
      ref.watch(deviceRegistrationRepositoryProvider),
      ref.watch(accessLocalDataSourceProvider),
      ref.watch(nodeActorEvidenceProvider),
      ref.watch(offlinePinRepositoryProvider),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  final repository = FirebaseAuthRepository(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    accessProfileRepository: ref.watch(accessProfileRepositoryProvider),
    activeContextRepository: ref.watch(activeContextRepositoryProvider),
    deviceRegistrationRepository: ref.watch(
      deviceRegistrationRepositoryProvider,
    ),
    accessRefreshInterval: config.accessRefreshInterval,
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
