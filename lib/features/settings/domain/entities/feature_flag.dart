import 'operational_setting.dart';

class FeatureFlag {
  const FeatureFlag({
    required this.id,
    required this.key,
    required this.isEnabled,
    required this.configuration,
    required this.scope,
    required this.version,
    this.branchId,
  });

  final String id;
  final String key;
  final bool isEnabled;
  final Map<String, Object?> configuration;
  final SettingScope scope;
  final int version;
  final String? branchId;
}
