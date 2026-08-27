enum CashMovementType {
  cashIn('cash_in', 'Cash in'),
  cashOut('cash_out', 'Cash out'),
  payout('payout', 'Payout'),
  correction('correction', 'Correction');

  const CashMovementType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static CashMovementType fromDatabase(String value) {
    return values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => CashMovementType.correction,
    );
  }
}

class CashMovement {
  const CashMovement({
    required this.id,
    required this.shiftId,
    required this.type,
    required this.amountMinor,
    required this.reason,
    required this.createdByUserId,
    required this.occurredAt,
  });

  final String id;
  final String shiftId;
  final CashMovementType type;
  final int amountMinor;
  final String reason;
  final String createdByUserId;
  final DateTime occurredAt;
}

class CashMovementDraft {
  const CashMovementDraft({
    required this.shiftId,
    required this.type,
    required this.amountMinor,
    required this.reason,
    this.operationId,
  });

  final String shiftId;
  final CashMovementType type;
  final int amountMinor;
  final String reason;
  final String? operationId;
}
