enum StockTransferStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  shipped('shipped', 'In transit'),
  received('received', 'Received'),
  cancelled('cancelled', 'Cancelled');

  const StockTransferStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static StockTransferStatus fromDatabase(String value) => values.firstWhere(
    (status) => status.databaseValue == value,
    orElse: () => throw FormatException('Unknown transfer status: $value'),
  );
}

class TransferBranchOption {
  const TransferBranchOption({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;
  final String name;
}

class TransferLocationOption {
  const TransferLocationOption({
    required this.id,
    required this.branchId,
    required this.name,
    required this.locationType,
    required this.isDefault,
  });

  final String id;
  final String branchId;
  final String name;
  final String locationType;
  final bool isDefault;
}

class TransferProductOption {
  const TransferProductOption({
    required this.id,
    required this.sku,
    required this.name,
  });

  final String id;
  final String sku;
  final String name;
}

class TransferOptions {
  const TransferOptions({
    required this.branches,
    required this.locations,
    required this.products,
  });

  final List<TransferBranchOption> branches;
  final List<TransferLocationOption> locations;
  final List<TransferProductOption> products;
}

class StockTransferLineDraft {
  const StockTransferLineDraft({
    required this.productId,
    required this.sourceStockLocationId,
    required this.destinationStockLocationId,
    required this.quantityMilli,
  });

  final String productId;
  final String sourceStockLocationId;
  final String destinationStockLocationId;
  final int quantityMilli;
}

class StockTransferDraft {
  const StockTransferDraft({
    required this.destinationBranchId,
    required this.lines,
    this.notes,
    this.operationId,
  });

  final String destinationBranchId;
  final List<StockTransferLineDraft> lines;
  final String? notes;
  final String? operationId;
}

class TransferReceiptLineDraft {
  const TransferReceiptLineDraft({
    required this.transferItemId,
    required this.receivedQuantityMilli,
    required this.damagedQuantityMilli,
    this.damagedStockLocationId,
  });

  final String transferItemId;
  final int receivedQuantityMilli;
  final int damagedQuantityMilli;
  final String? damagedStockLocationId;
}

class TransferReceiptDraft {
  const TransferReceiptDraft({
    required this.lines,
    this.notes,
    this.operationId,
  });

  final List<TransferReceiptLineDraft> lines;
  final String? notes;
  final String? operationId;
}

class TransferCorrectionLineDraft {
  const TransferCorrectionLineDraft({
    required this.transferItemId,
    required this.receivedQuantityMilli,
    required this.damagedQuantityMilli,
    this.damagedStockLocationId,
  });

  final String transferItemId;
  final int receivedQuantityMilli;
  final int damagedQuantityMilli;
  final String? damagedStockLocationId;
}

class TransferCorrectionDraft {
  const TransferCorrectionDraft({
    required this.reason,
    required this.lines,
    this.notes,
    this.operationId,
  });

  final String reason;
  final List<TransferCorrectionLineDraft> lines;
  final String? notes;
  final String? operationId;
}

class StockTransferLine {
  const StockTransferLine({
    required this.id,
    required this.productId,
    required this.sku,
    required this.productName,
    required this.sourceStockLocationId,
    required this.sourceLocationName,
    required this.destinationStockLocationId,
    required this.destinationLocationName,
    required this.requestedQuantityMilli,
    required this.shippedQuantityMilli,
    required this.receivedQuantityMilli,
    required this.damagedQuantityMilli,
    required this.discrepancyQuantityMilli,
    required this.version,
    this.damagedStockLocationId,
    this.damagedLocationName,
  });

  final String id;
  final String productId;
  final String sku;
  final String productName;
  final String sourceStockLocationId;
  final String sourceLocationName;
  final String destinationStockLocationId;
  final String destinationLocationName;
  final String? damagedStockLocationId;
  final String? damagedLocationName;
  final int requestedQuantityMilli;
  final int shippedQuantityMilli;
  final int receivedQuantityMilli;
  final int damagedQuantityMilli;
  final int discrepancyQuantityMilli;
  final int version;

  int get inTransitQuantityMilli =>
      shippedQuantityMilli - receivedQuantityMilli - damagedQuantityMilli;
}

class TransferEvent {
  const TransferEvent({
    required this.id,
    required this.eventType,
    required this.toStatus,
    required this.actorUserId,
    required this.occurredAt,
    this.fromStatus,
    this.reason,
  });

  final String id;
  final String eventType;
  final StockTransferStatus? fromStatus;
  final StockTransferStatus toStatus;
  final String actorUserId;
  final String? reason;
  final DateTime occurredAt;
}

class StockTransfer {
  const StockTransfer({
    required this.id,
    required this.transferNumber,
    required this.sourceBranchId,
    required this.sourceBranchName,
    required this.destinationBranchId,
    required this.destinationBranchName,
    required this.status,
    required this.approvalRequired,
    required this.createdByUserId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.lines,
    required this.events,
    this.notes,
    this.approvedByUserId,
    this.rejectionReason,
    this.cancellationReason,
  });

  final String id;
  final String transferNumber;
  final String sourceBranchId;
  final String sourceBranchName;
  final String destinationBranchId;
  final String destinationBranchName;
  final StockTransferStatus status;
  final bool approvalRequired;
  final String createdByUserId;
  final String? approvedByUserId;
  final String? notes;
  final String? rejectionReason;
  final String? cancellationReason;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<StockTransferLine> lines;
  final List<TransferEvent> events;

  int get totalRequestedQuantityMilli =>
      lines.fold(0, (total, line) => total + line.requestedQuantityMilli);

  int get totalDiscrepancyQuantityMilli =>
      lines.fold(0, (total, line) => total + line.discrepancyQuantityMilli);
}

class TransferPolicy {
  const TransferPolicy({this.approvalThresholdMilli});

  final int? approvalThresholdMilli;
}
