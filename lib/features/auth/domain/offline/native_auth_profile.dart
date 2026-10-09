class NativeAuthProfile {
  const NativeAuthProfile({
    required this.deploymentId,
    required this.organizationCode,
    required this.apiOrigin,
    required this.offlineVerificationKeys,
    this.allowHttpLoopback = false,
  });
  final String deploymentId;
  final String organizationCode;
  final Uri apiOrigin;
  final Map<String, Map<String, String>> offlineVerificationKeys;
  final bool allowHttpLoopback;
}
