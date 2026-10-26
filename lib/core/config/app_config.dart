import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_environment.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromDartDefines();
});

class AppConfig {
  static const defaultAccessRefreshInterval = Duration(minutes: 5);
  static const defaultMaxOfflineAccessAge = Duration(days: 7);

  const AppConfig({
    required this.environment,
    required this.enableDemoAuth,
    required this.enableDiagnostics,
    this.onlineOnly = false,
    this.accessRefreshInterval = defaultAccessRefreshInterval,
    this.maxOfflineAccessAge = defaultMaxOfflineAccessAge,
    this.apiBaseUri,
    this.demoBranchId,
  });

  factory AppConfig.fromDartDefines() {
    const environmentValue = String.fromEnvironment('JCE_ENV');
    const isReleaseBuild = bool.fromEnvironment('dart.vm.product');
    const isProfileBuild = bool.fromEnvironment('dart.vm.profile');
    final environmentWasExplicit = environmentValue.trim().isNotEmpty;
    final resolvedEnvironment = environmentWasExplicit
        ? environmentValue
        : 'development';
    const backend = String.fromEnvironment('JCE_BACKEND', defaultValue: 'node');
    const apiBaseUrl = String.fromEnvironment('JCE_API_BASE_URL');
    const demoAuthValue = String.fromEnvironment('JCE_ENABLE_DEMO_AUTH');
    const diagnosticsValue = String.fromEnvironment('JCE_ENABLE_DIAGNOSTICS');
    const onlineOnlyValue = String.fromEnvironment('JCE_ONLINE_ONLY');
    const demoBranchIdValue = String.fromEnvironment('JCE_DEMO_BRANCH_ID');
    const accessRefreshMinutes = String.fromEnvironment(
      'JCE_ACCESS_REFRESH_MINUTES',
    );
    const maxOfflineAccessHours = String.fromEnvironment(
      'JCE_MAX_OFFLINE_ACCESS_HOURS',
    );
    return AppConfig.fromValues(
      environment: resolvedEnvironment,
      backend: backend,
      apiBaseUrl: apiBaseUrl,
      enableDemoAuth: demoAuthValue,
      enableDiagnostics: diagnosticsValue,
      onlineOnly: onlineOnlyValue,
      demoBranchId: demoBranchIdValue,
      accessRefreshMinutes: accessRefreshMinutes,
      maxOfflineAccessHours: maxOfflineAccessHours,
      enforceReleaseSafety: isReleaseBuild || isProfileBuild,
      environmentWasExplicit: environmentWasExplicit,
    );
  }

  factory AppConfig.fromValues({
    required String environment,
    String backend = 'node',
    String? apiBaseUrl,
    String? enableDemoAuth,
    String? enableDiagnostics,
    String? onlineOnly,
    String? demoBranchId,
    String? accessRefreshMinutes,
    String? maxOfflineAccessHours,
    bool enforceReleaseSafety = false,
    bool environmentWasExplicit = true,
  }) {
    if (backend != 'node') {
      throw const FormatException(
        'JCE_BACKEND must be node; legacy profiles are unsupported.',
      );
    }
    if (enforceReleaseSafety && !environmentWasExplicit) {
      throw const FormatException(
        'JCE_ENV is required for profile and release builds.',
      );
    }
    final parsedEnvironment = AppEnvironment.parse(environment);
    final parsedApiBaseUri = _parseAbsoluteUri(apiBaseUrl);
    final parsedEnableDemoAuth = _parseOptionalBool(
      enableDemoAuth,
      fallback: false,
      key: 'JCE_ENABLE_DEMO_AUTH',
    );
    final parsedEnableDiagnostics = _parseOptionalBool(
      enableDiagnostics,
      fallback: !parsedEnvironment.isProduction,
      key: 'JCE_ENABLE_DIAGNOSTICS',
    );
    final parsedOnlineOnly = _parseOptionalBool(
      onlineOnly,
      fallback: false,
      key: 'JCE_ONLINE_ONLY',
    );
    final normalizedDemoBranchId = _normalizeOptional(demoBranchId);
    final parsedAccessRefreshMinutes = _parsePositiveInt(
      accessRefreshMinutes,
      fallback: defaultAccessRefreshInterval.inMinutes,
      key: 'JCE_ACCESS_REFRESH_MINUTES',
    );
    final parsedMaxOfflineAccessHours = _parsePositiveInt(
      maxOfflineAccessHours,
      fallback: defaultMaxOfflineAccessAge.inHours,
      key: 'JCE_MAX_OFFLINE_ACCESS_HOURS',
    );
    if (parsedEnableDemoAuth && normalizedDemoBranchId == null) {
      throw const FormatException(
        'JCE_DEMO_BRANCH_ID is required when demo authentication is enabled.',
      );
    }
    if (parsedEnableDemoAuth &&
        parsedEnvironment != AppEnvironment.development) {
      throw const FormatException(
        'Demo authentication can only be enabled in development.',
      );
    }
    if (enforceReleaseSafety &&
        parsedEnvironment == AppEnvironment.development) {
      throw const FormatException(
        'Development cannot be selected for a profile or release build.',
      );
    }
    if (parsedEnvironment.isProduction && parsedEnableDiagnostics) {
      throw const FormatException(
        'JCE_ENABLE_DIAGNOSTICS must be false in production.',
      );
    }
    if (parsedOnlineOnly && parsedApiBaseUri == null) {
      throw const FormatException(
        'JCE_API_BASE_URL is required when JCE_ONLINE_ONLY is true.',
      );
    }
    if (parsedOnlineOnly && parsedEnableDemoAuth) {
      throw const FormatException(
        'Demo authentication is unavailable in online-only mode.',
      );
    }

    return AppConfig(
      environment: parsedEnvironment,
      apiBaseUri: parsedApiBaseUri,
      enableDemoAuth: parsedEnableDemoAuth,
      enableDiagnostics: parsedEnableDiagnostics,
      onlineOnly: parsedOnlineOnly,
      demoBranchId: normalizedDemoBranchId,
      accessRefreshInterval: Duration(minutes: parsedAccessRefreshMinutes),
      maxOfflineAccessAge: Duration(hours: parsedMaxOfflineAccessHours),
    );
  }

  final AppEnvironment environment;
  final Uri? apiBaseUri;
  final bool enableDemoAuth;
  final bool enableDiagnostics;
  final bool onlineOnly;
  final String? demoBranchId;
  final Duration accessRefreshInterval;
  final Duration maxOfflineAccessAge;

  static Uri? _parseAbsoluteUri(String? value) {
    final normalized = _normalizeOptional(value);
    if (normalized == null) {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException(
        'JCE_API_BASE_URL must be an absolute URL when provided.',
      );
    }
    return uri;
  }

  static bool _parseOptionalBool(
    String? value, {
    required bool fallback,
    required String key,
  }) {
    final normalized = _normalizeOptional(value)?.toLowerCase();
    if (normalized == null) {
      return fallback;
    }

    return switch (normalized) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => throw FormatException('$key must be true or false.'),
    };
  }

  static int _parsePositiveInt(
    String? value, {
    required int fallback,
    required String key,
  }) {
    final normalized = _normalizeOptional(value);
    if (normalized == null) {
      return fallback;
    }
    final parsed = int.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      throw FormatException('$key must be a positive integer.');
    }
    return parsed;
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
