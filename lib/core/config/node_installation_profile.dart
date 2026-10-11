import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/domain/offline/native_auth_profile.dart';
import 'app_environment.dart';
import 'release_config_validator.dart';

NativeAuthProfile nodeInstallationProfile() {
  const deployment = String.fromEnvironment('JCE_DEPLOYMENT_ID');
  const organization = String.fromEnvironment('JCE_ORGANIZATION_CODE');
  const origin = String.fromEnvironment('JCE_API_BASE_URL');
  const keysJson = String.fromEnvironment('JCE_OFFLINE_VERIFICATION_KEYS');
  const loopback = bool.fromEnvironment('JCE_ALLOW_HTTP_LOOPBACK');
  const environment = String.fromEnvironment('JCE_ENV');
  if (AppEnvironment.parse(
    environment.trim().isEmpty ? 'development' : environment,
  ).isProduction) {
    ReleaseConfigValidator.ensureValid(
      values: {
        'JCE_ENV': environment,
        'JCE_BACKEND': const String.fromEnvironment(
          'JCE_BACKEND',
          defaultValue: 'node',
        ),
        'JCE_ENABLE_DEMO_AUTH': const String.fromEnvironment(
          'JCE_ENABLE_DEMO_AUTH',
        ),
        'JCE_ENABLE_DIAGNOSTICS': const String.fromEnvironment(
          'JCE_ENABLE_DIAGNOSTICS',
        ),
        'JCE_API_BASE_URL': origin,
        'JCE_DEPLOYMENT_ID': deployment,
        'JCE_ORGANIZATION_CODE': organization,
        'JCE_OFFLINE_VERIFICATION_KEYS': keysJson,
        'JCE_ALLOW_HTTP_LOOPBACK': '$loopback',
      },
      platform: kIsWeb
          ? ReleasePlatform.web
          : defaultTargetPlatform == TargetPlatform.windows
          ? ReleasePlatform.windows
          : ReleasePlatform.android,
      expectedDeploymentId: const String.fromEnvironment(
        'JCE_APPROVED_PRODUCTION_DEPLOYMENT_ID',
      ),
    );
  }
  if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(deployment) ||
      organization.trim().isEmpty ||
      keysJson.isEmpty) {
    throw const FormatException(
      'Install a deployment profile with API origin, deployment ID, organization code and pinned verification keys.',
    );
  }
  final keys = jsonDecode(keysJson) as Map;
  if (keys.isEmpty) {
    throw const FormatException(
      'At least one pinned verification key is required.',
    );
  }
  return NativeAuthProfile(
    deploymentId: deployment,
    organizationCode: organization,
    apiOrigin: Uri.parse(origin),
    allowHttpLoopback: loopback,
    offlineVerificationKeys: keys.map(
      (key, value) =>
          MapEntry(key as String, Map<String, String>.from(value as Map)),
    ),
  );
}

String deploymentDatabaseName(String deploymentId) =>
    'jce_node_${sha256.convert(utf8.encode(deploymentId))}';
