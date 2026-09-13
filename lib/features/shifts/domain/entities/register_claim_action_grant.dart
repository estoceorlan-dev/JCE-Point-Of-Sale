class RegisterClaimActionGrant {
  const RegisterClaimActionGrant({
    required this.id,
    required this.nonce,
    required this.managerUserId,
    required this.expiresAt,
  });

  final String id;
  final String nonce;
  final String managerUserId;
  final DateTime expiresAt;
}
