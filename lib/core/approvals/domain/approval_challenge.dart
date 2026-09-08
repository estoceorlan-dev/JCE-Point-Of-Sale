/// A snapshot of one protected operation, never a reusable manager session.
/// The workflow must derive [operationDigest] from its canonical persisted data.
class ApprovalChallenge {
  const ApprovalChallenge({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.requestedByUserId,
    required this.deviceId,
    required this.operationId,
    required this.operationType,
    required this.aggregateId,
    required this.operationDigest,
    required this.permissionCode,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String organizationId;
  final String branchId;
  final String requestedByUserId;
  final String deviceId;
  final String operationId;
  final String operationType;
  final String aggregateId;
  final String operationDigest;
  final String permissionCode;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool isValidAt(DateTime now) =>
      [
        id,
        organizationId,
        branchId,
        requestedByUserId,
        deviceId,
        operationId,
        operationType,
        aggregateId,
        permissionCode,
      ].every((value) => value.trim().isNotEmpty) &&
      RegExp(r'^[0-9a-f]{64}$').hasMatch(operationDigest) &&
      createdAt.isBefore(expiresAt) &&
      !now.isBefore(createdAt) &&
      now.isBefore(expiresAt);

  bool hasSameBinding(ApprovalChallenge other) =>
      id == other.id &&
      organizationId == other.organizationId &&
      branchId == other.branchId &&
      requestedByUserId == other.requestedByUserId &&
      deviceId == other.deviceId &&
      operationId == other.operationId &&
      operationType == other.operationType &&
      aggregateId == other.aggregateId &&
      operationDigest == other.operationDigest &&
      permissionCode == other.permissionCode &&
      createdAt == other.createdAt &&
      expiresAt == other.expiresAt;
}
