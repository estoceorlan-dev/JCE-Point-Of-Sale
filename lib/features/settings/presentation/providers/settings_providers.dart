import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/drift_settings_repository.dart';
import '../../domain/entities/feature_flag.dart';
import '../../domain/entities/operational_setting.dart';
import '../../domain/entities/reason_code.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/use_cases/save_feature_flag_use_case.dart';
import '../../domain/use_cases/save_operational_setting_use_case.dart';
import '../../domain/use_cases/save_reason_code_use_case.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return DriftSettingsRepository(
    database: ref.watch(appDatabaseProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final operationalSettingsProvider = StreamProvider<OperationalSettings>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(OperationalSettings.defaults());
  return ref
      .watch(settingsRepositoryProvider)
      .watchResolvedSettings(context: context);
});

final reasonCodesProvider = StreamProvider<List<ReasonCode>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref
      .watch(settingsRepositoryProvider)
      .watchReasonCodes(context: context, includeInactive: true);
});

final featureFlagsProvider = StreamProvider<List<FeatureFlag>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref
      .watch(settingsRepositoryProvider)
      .watchFeatureFlags(context: context);
});

final saveOperationalSettingUseCaseProvider =
    Provider<SaveOperationalSettingUseCase>(
      (ref) => SaveOperationalSettingUseCase(
        repository: ref.watch(settingsRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final saveReasonCodeUseCaseProvider = Provider<SaveReasonCodeUseCase>(
  (ref) => SaveReasonCodeUseCase(
    repository: ref.watch(settingsRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final saveFeatureFlagUseCaseProvider = Provider<SaveFeatureFlagUseCase>(
  (ref) => SaveFeatureFlagUseCase(
    repository: ref.watch(settingsRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);
