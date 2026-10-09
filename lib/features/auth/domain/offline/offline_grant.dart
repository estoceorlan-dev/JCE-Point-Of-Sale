class OfflineGrant {
  const OfflineGrant({
    required this.enrollmentId,
    required this.deploymentId,
    required this.identityId,
    required this.userId,
    required this.organizationId,
    required this.branchId,
    required this.deviceId,
    required this.keyThumbprint,
    required this.displayName,
    required this.permissions,
    required this.issuedAt,
    required this.expiresAt,
  });
  final String enrollmentId;
  final String deploymentId;
  final String identityId;
  final String userId;
  final String organizationId;
  final String branchId;
  final String deviceId;
  final String keyThumbprint;
  final String displayName;
  final Set<String> permissions;
  final DateTime issuedAt;
  final DateTime expiresAt;

  // PIN sessions never satisfy a supervisor authorization challenge.
  bool get canApproveAsSupervisor => false;
  bool can(String permission, DateTime now) =>
      now.isBefore(expiresAt) && permissions.contains(permission);
}

abstract interface class OfflineGrantVerifier {
  OfflineGrant verify(
    String authorization, {
    required String deviceId,
    required String keyThumbprint,
    required DateTime now,
  });
}
