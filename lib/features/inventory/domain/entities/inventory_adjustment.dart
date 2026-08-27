class InventoryAdjustmentDraft {
  const InventoryAdjustmentDraft({
    required this.stockLocationId,
    required this.productId,
    required this.quantityDeltaMilli,
    required this.reasonCode,
    this.notes,
    this.expectedBalanceVersion,
    this.operationId,
  });

  final String stockLocationId;
  final String productId;
  final int quantityDeltaMilli;
  final String reasonCode;
  final String? notes;
  final int? expectedBalanceVersion;
  final String? operationId;
}

class InventoryPolicy {
  const InventoryPolicy({
    required this.allowNegativeStock,
    this.adjustmentApprovalThresholdMilli,
  });

  final bool allowNegativeStock;
  final int? adjustmentApprovalThresholdMilli;
}
