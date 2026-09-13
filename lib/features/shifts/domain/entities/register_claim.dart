enum RegisterClaimStatus {
  provisional,
  accepted,
  rejected,
  resolved,
  released;

  static RegisterClaimStatus fromDatabase(String value) => values.firstWhere(
    (status) => status.name == value,
    orElse: () => provisional,
  );
}

class RegisterClaim {
  const RegisterClaim({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.requestedRegisterId,
    required this.deviceId,
    required this.claimedByUserId,
    required this.status,
    required this.version,
    required this.createdAt,
    this.resolvedRegisterId,
    this.rejectionCode,
    this.rejectionMessage,
  });

  final String id;
  final String organizationId;
  final String branchId;
  final String requestedRegisterId;
  final String? resolvedRegisterId;
  final String deviceId;
  final String claimedByUserId;
  final RegisterClaimStatus status;
  final String? rejectionCode;
  final String? rejectionMessage;
  final int version;
  final DateTime createdAt;

  String get effectiveRegisterId => resolvedRegisterId ?? requestedRegisterId;

  bool get isOperational => switch (status) {
    RegisterClaimStatus.provisional ||
    RegisterClaimStatus.accepted ||
    RegisterClaimStatus.resolved => true,
    RegisterClaimStatus.rejected || RegisterClaimStatus.released => false,
  };
}
