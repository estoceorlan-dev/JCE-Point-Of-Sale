import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../features/auth/domain/offline/native_auth_profile.dart';

NativeAuthProfile nodeInstallationProfile() {
  const deployment = String.fromEnvironment('JCE_DEPLOYMENT_ID');
  const organization = String.fromEnvironment('JCE_ORGANIZATION_CODE');
  const origin = String.fromEnvironment('JCE_API_BASE_URL');
  const keysJson = String.fromEnvironment('JCE_OFFLINE_VERIFICATION_KEYS');
  const loopback = bool.fromEnvironment('JCE_ALLOW_HTTP_LOOPBACK');
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
