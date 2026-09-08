import 'approval_challenge.dart';

/// Non-secret decision metadata. Constructing this object proves no authority.
/// Signed evidence belongs in secure storage under [id], never in audit JSON.
class ApprovalGrant {
  const ApprovalGrant({
    required this.id,
    required this.challenge,
    required this.approverUserId,
    required this.credentialId,
    required this.approvedAt,
    required this.expiresAt,
  });

  final String id;
  final ApprovalChallenge challenge;
  final String approverUserId;
  final String credentialId;
  final DateTime approvedAt;
  final DateTime expiresAt;

  /// Only checks metadata binding and time. The service must ALSO verify signed
  /// evidence, credential scope/revocation, and transactional single-use claims.
  bool hasValidBinding(ApprovalChallenge expected, DateTime now) =>
      id.trim().isNotEmpty &&
      approverUserId.trim().isNotEmpty &&
      credentialId.trim().isNotEmpty &&
      challenge.hasSameBinding(expected) &&
      expected.isValidAt(now) &&
      !approvedAt.isBefore(expected.createdAt) &&
      !approvedAt.isAfter(now) &&
      approvedAt.isBefore(expiresAt) &&
      !expiresAt.isAfter(expected.expiresAt) &&
      now.isBefore(expiresAt);
}
