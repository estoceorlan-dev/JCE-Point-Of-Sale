import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/feature_flag.dart';
import '../entities/operational_setting.dart';
import '../entities/reason_code.dart';

abstract interface class SettingsRepository {
  Stream<OperationalSettings> watchResolvedSettings({
    required BusinessContext context,
  });

  Future<Result<void, Failure>> saveSetting({
    required BusinessContext context,
    required SettingScope scope,
    required OperationalSettingKey key,
    required Object? value,
    String? operationId,
  });

  Future<Result<void, Failure>> clearBranchOverride({
    required BusinessContext context,
    required OperationalSettingKey key,
    String? operationId,
  });

  Stream<List<ReasonCode>> watchReasonCodes({
    required BusinessContext context,
    ReasonCodeCategory? category,
    bool includeInactive = false,
  });

  Future<Result<String, Failure>> saveReasonCode({
    required BusinessContext context,
    required ReasonCodeDraft draft,
  });

  Stream<List<FeatureFlag>> watchFeatureFlags({
    required BusinessContext context,
  });

  Future<Result<void, Failure>> saveFeatureFlag({
    required BusinessContext context,
    required String key,
    required bool isEnabled,
    required SettingScope scope,
    Map<String, Object?> configuration = const {},
    String? operationId,
  });
}
