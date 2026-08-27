import 'cash_movement.dart';

enum CashShiftStatus {
  open('open', 'Open'),
  closed('closed', 'Closed');

  const CashShiftStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static CashShiftStatus fromDatabase(String value) {
    return value == 'open' ? CashShiftStatus.open : CashShiftStatus.closed;
  }
}

enum ShiftPaymentMethod {
  cash('cash', 'Cash'),
  card('card', 'Card'),
  eWallet('e_wallet', 'E-wallet');

  const ShiftPaymentMethod(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ShiftPaymentMethod fromDatabase(String value) {
    return values.firstWhere(
      (method) => method.databaseValue == value,
      orElse: () => ShiftPaymentMethod.cash,
    );
  }
}

class ShiftCount {
  const ShiftCount({
    required this.paymentMethod,
    required this.expectedAmountMinor,
    required this.countedAmountMinor,
    required this.discrepancyMinor,
  });

  final ShiftPaymentMethod paymentMethod;
  final int expectedAmountMinor;
  final int countedAmountMinor;
  final int discrepancyMinor;
}

class CashShift {
  const CashShift({
    required this.id,
    required this.registerId,
    required this.registerName,
    required this.deviceId,
    required this.status,
    required this.openingCashMinor,
    required this.openedByUserId,
    required this.openedAt,
    required this.movements,
    required this.counts,
    required this.version,
    this.cashSalesMinor = 0,
    this.cardSalesMinor = 0,
    this.eWalletSalesMinor = 0,
    this.expectedCashMinorAtClose,
    this.countedCashMinor,
    this.discrepancyMinor,
    this.closedByUserId,
    this.closedAt,
    this.approvedByUserId,
    this.approvedAt,
    this.approvalNotes,
  });

  final String id;
  final String registerId;
  final String registerName;
  final String deviceId;
  final CashShiftStatus status;
  final int openingCashMinor;
  final String openedByUserId;
  final DateTime openedAt;
  final List<CashMovement> movements;
  final List<ShiftCount> counts;
  final int version;
  final int cashSalesMinor;
  final int cardSalesMinor;
  final int eWalletSalesMinor;
  final int? expectedCashMinorAtClose;
  final int? countedCashMinor;
  final int? discrepancyMinor;
  final String? closedByUserId;
  final DateTime? closedAt;
  final String? approvedByUserId;
  final DateTime? approvedAt;
  final String? approvalNotes;

  int get cashMovementTotalMinor =>
      movements.fold(0, (total, movement) => total + movement.amountMinor);

  int get expectedCashMinor =>
      openingCashMinor + cashMovementTotalMinor + cashSalesMinor;
}

class OpenShiftDraft {
  const OpenShiftDraft({
    required this.registerId,
    required this.deviceId,
    required this.openingCashMinor,
    this.notes,
    this.operationId,
  });

  final String registerId;
  final String deviceId;
  final int openingCashMinor;
  final String? notes;
  final String? operationId;
}

class CloseShiftDraft {
  const CloseShiftDraft({
    required this.shiftId,
    required this.countedAmountsMinor,
    required this.expectedVersion,
    this.notes,
    this.approvalNotes,
    this.operationId,
  });

  final String shiftId;
  final Map<ShiftPaymentMethod, int> countedAmountsMinor;
  final int expectedVersion;
  final String? notes;
  final String? approvalNotes;
  final String? operationId;
}

class ShiftPolicy {
  const ShiftPolicy({
    required this.allowMultipleOpenShiftsPerUser,
    required this.allowSalesWithoutOpenShift,
    this.cashDiscrepancyApprovalThresholdMinor,
  });

  final bool allowMultipleOpenShiftsPerUser;
  final bool allowSalesWithoutOpenShift;
  final int? cashDiscrepancyApprovalThresholdMinor;
}
