enum LoyaltyEntryType {
  earn,
  redeem,
  adjustment,
  expiry,
  reversal,
  mergeIn,
  mergeOut;

  String get databaseValue => switch (this) {
    mergeIn => 'merge_in',
    mergeOut => 'merge_out',
    _ => name,
  };

  String get label => switch (this) {
    earn => 'Earned',
    redeem => 'Redeemed',
    adjustment => 'Adjustment',
    expiry => 'Expired',
    reversal => 'Reversal',
    mergeIn => 'Merge credit',
    mergeOut => 'Merge transfer',
  };

  static LoyaltyEntryType fromDatabase(String value) => values.firstWhere(
    (type) => type.databaseValue == value,
    orElse: () => LoyaltyEntryType.adjustment,
  );
}

class LoyaltyLedgerEntry {
  const LoyaltyLedgerEntry({
    required this.id,
    required this.operationId,
    required this.type,
    required this.pointsDelta,
    required this.balanceAfter,
    required this.reason,
    required this.createdByUserId,
    required this.occurredAt,
    this.saleId,
  });

  final String id;
  final String operationId;
  final LoyaltyEntryType type;
  final int pointsDelta;
  final int balanceAfter;
  final String reason;
  final String createdByUserId;
  final DateTime occurredAt;
  final String? saleId;
}

class LoyaltyAccount {
  const LoyaltyAccount({
    required this.id,
    required this.status,
    required this.pointsBalance,
    required this.lifetimeEarnedPoints,
    required this.lifetimeRedeemedPoints,
    required this.version,
    required this.entries,
  });

  final String id;
  final String status;
  final int pointsBalance;
  final int lifetimeEarnedPoints;
  final int lifetimeRedeemedPoints;
  final int version;
  final List<LoyaltyLedgerEntry> entries;
}
