import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_environment.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromDartDefines();
});

class AppConfig {
  static const defaultFirebaseFunctionsRegion = 'asia-southeast1';
  static const defaultAccessRefreshInterval = Duration(minutes: 5);
  static const defaultMaxOfflineAccessAge = Duration(hours: 24);

  const AppConfig({
    required this.environment,
    required this.enableDemoAuth,
    required this.enableDiagnostics,
    this.accessProfileFunctionName = 'getMyAccessProfile',
    this.deviceRegistrationFunctionName = 'registerDevice',
    this.updateBranchNameFunctionName = 'updateBranchName',
    this.remoteCommandFunctionName = 'applyRemoteCommand',
    this.finalizeProductImageFunctionName = 'finalizeProductImage',
    this.generateStaffInviteFunctionName = 'generateStaffInviteLink',
    this.acceptStaffInviteFunctionName = 'acceptStaffInvitation',
    this.administrationSnapshotFunctionName = 'getAdministrationSnapshot',
    this.accessRefreshInterval = defaultAccessRefreshInterval,
    this.maxOfflineAccessAge = defaultMaxOfflineAccessAge,
    this.apiBaseUri,
    this.demoBranchId,
    this.firebaseFunctionsRegion,
  });

  factory AppConfig.fromDartDefines() {
    const environmentValue = String.fromEnvironment(
      'JCE_ENV',
      defaultValue: 'development',
    );
    const apiBaseUrl = String.fromEnvironment('JCE_API_BASE_URL');
    const demoAuthValue = String.fromEnvironment('JCE_ENABLE_DEMO_AUTH');
    const diagnosticsValue = String.fromEnvironment('JCE_ENABLE_DIAGNOSTICS');
    const demoBranchIdValue = String.fromEnvironment('JCE_DEMO_BRANCH_ID');
    const functionsRegion = String.fromEnvironment(
      'JCE_FIREBASE_FUNCTIONS_REGION',
      defaultValue: defaultFirebaseFunctionsRegion,
    );
    const accessProfileFunction = String.fromEnvironment(
      'JCE_ACCESS_PROFILE_FUNCTION',
      defaultValue: 'getMyAccessProfile',
    );
    const deviceRegistrationFunction = String.fromEnvironment(
      'JCE_DEVICE_REGISTRATION_FUNCTION',
      defaultValue: 'registerDevice',
    );
    const updateBranchNameFunction = String.fromEnvironment(
      'JCE_UPDATE_BRANCH_NAME_FUNCTION',
      defaultValue: 'updateBranchName',
    );
    const remoteCommandFunction = String.fromEnvironment(
      'JCE_REMOTE_COMMAND_FUNCTION',
      defaultValue: 'applyRemoteCommand',
    );
    const finalizeProductImageFunction = String.fromEnvironment(
      'JCE_FINALIZE_PRODUCT_IMAGE_FUNCTION',
      defaultValue: 'finalizeProductImage',
    );
    const generateStaffInviteFunction = String.fromEnvironment(
      'JCE_GENERATE_STAFF_INVITE_FUNCTION',
      defaultValue: 'generateStaffInviteLink',
    );
    const acceptStaffInviteFunction = String.fromEnvironment(
      'JCE_ACCEPT_STAFF_INVITE_FUNCTION',
      defaultValue: 'acceptStaffInvitation',
    );
    const administrationSnapshotFunction = String.fromEnvironment(
      'JCE_ADMINISTRATION_SNAPSHOT_FUNCTION',
      defaultValue: 'getAdministrationSnapshot',
    );
    const accessRefreshMinutes = String.fromEnvironment(
      'JCE_ACCESS_REFRESH_MINUTES',
    );
    const maxOfflineAccessHours = String.fromEnvironment(
      'JCE_MAX_OFFLINE_ACCESS_HOURS',
    );
    return AppConfig.fromValues(
      environment: environmentValue,
      apiBaseUrl: apiBaseUrl,
      enableDemoAuth: demoAuthValue,
      enableDiagnostics: diagnosticsValue,
      demoBranchId: demoBranchIdValue,
      firebaseFunctionsRegion: functionsRegion,
      accessProfileFunctionName: accessProfileFunction,
      deviceRegistrationFunctionName: deviceRegistrationFunction,
      updateBranchNameFunctionName: updateBranchNameFunction,
      remoteCommandFunctionName: remoteCommandFunction,
      finalizeProductImageFunctionName: finalizeProductImageFunction,
      generateStaffInviteFunctionName: generateStaffInviteFunction,
      acceptStaffInviteFunctionName: acceptStaffInviteFunction,
      administrationSnapshotFunctionName: administrationSnapshotFunction,
      accessRefreshMinutes: accessRefreshMinutes,
      maxOfflineAccessHours: maxOfflineAccessHours,
    );
  }

  factory AppConfig.fromValues({
    required String environment,
    String? apiBaseUrl,
    String? enableDemoAuth,
    String? enableDiagnostics,
    String? demoBranchId,
    String? firebaseFunctionsRegion,
    String accessProfileFunctionName = 'getMyAccessProfile',
    String deviceRegistrationFunctionName = 'registerDevice',
    String updateBranchNameFunctionName = 'updateBranchName',
    String remoteCommandFunctionName = 'applyRemoteCommand',
    String finalizeProductImageFunctionName = 'finalizeProductImage',
    String generateStaffInviteFunctionName = 'generateStaffInviteLink',
    String acceptStaffInviteFunctionName = 'acceptStaffInvitation',
    String administrationSnapshotFunctionName = 'getAdministrationSnapshot',
    String? accessRefreshMinutes,
    String? maxOfflineAccessHours,
  }) {
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
    final normalizedDemoBranchId = _normalizeOptional(demoBranchId);
    final normalizedFunctionsRegion =
        _normalizeOptional(firebaseFunctionsRegion) ??
        defaultFirebaseFunctionsRegion;
    final normalizedAccessProfileFunction = _requireValue(
      accessProfileFunctionName,
      key: 'JCE_ACCESS_PROFILE_FUNCTION',
    );
    final normalizedDeviceRegistrationFunction = _requireValue(
      deviceRegistrationFunctionName,
      key: 'JCE_DEVICE_REGISTRATION_FUNCTION',
    );
    final normalizedUpdateBranchNameFunction = _requireValue(
      updateBranchNameFunctionName,
      key: 'JCE_UPDATE_BRANCH_NAME_FUNCTION',
    );
    final normalizedRemoteCommandFunction = _requireValue(
      remoteCommandFunctionName,
      key: 'JCE_REMOTE_COMMAND_FUNCTION',
    );
    final normalizedFinalizeProductImageFunction = _requireValue(
      finalizeProductImageFunctionName,
      key: 'JCE_FINALIZE_PRODUCT_IMAGE_FUNCTION',
    );
    final normalizedGenerateStaffInviteFunction = _requireValue(
      generateStaffInviteFunctionName,
      key: 'JCE_GENERATE_STAFF_INVITE_FUNCTION',
    );
    final normalizedAcceptStaffInviteFunction = _requireValue(
      acceptStaffInviteFunctionName,
      key: 'JCE_ACCEPT_STAFF_INVITE_FUNCTION',
    );
    final normalizedAdministrationSnapshotFunction = _requireValue(
      administrationSnapshotFunctionName,
      key: 'JCE_ADMINISTRATION_SNAPSHOT_FUNCTION',
    );
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

    return AppConfig(
      environment: parsedEnvironment,
      apiBaseUri: parsedApiBaseUri,
      enableDemoAuth: parsedEnableDemoAuth,
      enableDiagnostics: parsedEnableDiagnostics,
      demoBranchId: normalizedDemoBranchId,
      firebaseFunctionsRegion: normalizedFunctionsRegion,
      accessProfileFunctionName: normalizedAccessProfileFunction,
      deviceRegistrationFunctionName: normalizedDeviceRegistrationFunction,
      updateBranchNameFunctionName: normalizedUpdateBranchNameFunction,
      remoteCommandFunctionName: normalizedRemoteCommandFunction,
      finalizeProductImageFunctionName: normalizedFinalizeProductImageFunction,
      generateStaffInviteFunctionName: normalizedGenerateStaffInviteFunction,
      acceptStaffInviteFunctionName: normalizedAcceptStaffInviteFunction,
      administrationSnapshotFunctionName:
          normalizedAdministrationSnapshotFunction,
      accessRefreshInterval: Duration(minutes: parsedAccessRefreshMinutes),
      maxOfflineAccessAge: Duration(hours: parsedMaxOfflineAccessHours),
    );
  }

  final AppEnvironment environment;
  final Uri? apiBaseUri;
  final bool enableDemoAuth;
  final bool enableDiagnostics;
  final String? demoBranchId;
  final String? firebaseFunctionsRegion;
  final String accessProfileFunctionName;
  final String deviceRegistrationFunctionName;
  final String updateBranchNameFunctionName;
  final String remoteCommandFunctionName;
  final String finalizeProductImageFunctionName;
  final String generateStaffInviteFunctionName;
  final String acceptStaffInviteFunctionName;
  final String administrationSnapshotFunctionName;
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

  static String _requireValue(String value, {required String key}) {
    final normalized = _normalizeOptional(value);
    if (normalized == null) {
      throw FormatException('$key cannot be empty.');
    }
    return normalized;
  }
}
