enum SaleCorrectionType {
  saleReturn('return', 'Return'),
  voidSale('void', 'Void');

  const SaleCorrectionType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static SaleCorrectionType fromDatabase(String value) => values.firstWhere(
    (type) => type.databaseValue == value,
    orElse: () => throw FormatException('Unknown sale correction type: $value'),
  );
}

enum ReturnDisposition {
  restock('restock', 'Restock'),
  damaged('damaged', 'Damaged'),
  nonRestock('non_restock', 'Do not restock');

  const ReturnDisposition(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  bool get changesInventory => this != ReturnDisposition.nonRestock;

  static ReturnDisposition fromDatabase(String value) => values.firstWhere(
    (disposition) => disposition.databaseValue == value,
    orElse: () => throw FormatException('Unknown return disposition: $value'),
  );
}

enum RefundMethod {
  cash('cash', 'Cash'),
  card('card', 'Card'),
  eWallet('e_wallet', 'E-wallet'),
  storeCredit('store_credit', 'Store credit');

  const RefundMethod(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static RefundMethod fromDatabase(String value) => values.firstWhere(
    (method) => method.databaseValue == value,
    orElse: () => throw FormatException('Unknown refund method: $value'),
  );
}

class ReturnDestination {
  const ReturnDestination({
    required this.stockLocationId,
    required this.name,
    required this.locationType,
    required this.isDefault,
  });

  final String stockLocationId;
  final String name;
  final String locationType;
  final bool isDefault;
}

class SaleCorrectionLineDraft {
  const SaleCorrectionLineDraft({
    required this.saleItemId,
    required this.quantityMilli,
    required this.disposition,
    this.destinationStockLocationId,
  });

  final String saleItemId;
  final int quantityMilli;
  final ReturnDisposition disposition;
  final String? destinationStockLocationId;
}

class RefundDraft {
  const RefundDraft({
    required this.method,
    required this.amountMinor,
    this.reference,
  });

  final RefundMethod method;
  final int amountMinor;
  final String? reference;
}

class SaleCorrectionDraft {
  const SaleCorrectionDraft({
    required this.saleId,
    required this.type,
    required this.lines,
    required this.refunds,
    required this.reasonCode,
    required this.deviceId,
    this.notes,
    this.operationId,
  });

  final String saleId;
  final SaleCorrectionType type;
  final List<SaleCorrectionLineDraft> lines;
  final List<RefundDraft> refunds;
  final String reasonCode;
  final String deviceId;
  final String? notes;
  final String? operationId;
}

class SaleCorrectionItem {
  const SaleCorrectionItem({
    required this.id,
    required this.saleItemId,
    required this.productId,
    required this.productName,
    required this.quantityMilli,
    required this.disposition,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
    this.destinationStockLocationId,
    this.destinationName,
  });

  final String id;
  final String saleItemId;
  final String productId;
  final String productName;
  final int quantityMilli;
  final ReturnDisposition disposition;
  final String? destinationStockLocationId;
  final String? destinationName;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
}

class RefundRecord {
  const RefundRecord({
    required this.id,
    required this.method,
    required this.amountMinor,
    this.reference,
  });

  final String id;
  final RefundMethod method;
  final int amountMinor;
  final String? reference;
}

class SaleCorrectionRecord {
  const SaleCorrectionRecord({
    required this.id,
    required this.returnNumber,
    required this.type,
    required this.status,
    required this.reasonCode,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
    required this.createdByUserId,
    required this.completedAt,
    required this.items,
    required this.refunds,
    this.notes,
    this.approvedByUserId,
  });

  final String id;
  final String returnNumber;
  final SaleCorrectionType type;
  final String status;
  final String reasonCode;
  final String? notes;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
  final String createdByUserId;
  final String? approvedByUserId;
  final DateTime completedAt;
  final List<SaleCorrectionItem> items;
  final List<RefundRecord> refunds;
}

class SaleCorrectionResult {
  const SaleCorrectionResult({
    required this.correctionId,
    required this.returnNumber,
  });

  final String correctionId;
  final String returnNumber;
}

class SaleCorrectionPolicy {
  const SaleCorrectionPolicy({
    this.returnApprovalThresholdMinor,
    this.voidWindowMinutes = 15,
  });

  final int? returnApprovalThresholdMinor;
  final int voidWindowMinutes;
}
