class GoodsReceiptLineDraft {
  const GoodsReceiptLineDraft({
    required this.purchaseOrderItemId,
    required this.receivedQuantityMilli,
    required this.unitCostMinor,
    this.freightCostMinor = 0,
    this.dutyCostMinor = 0,
    this.otherLandedCostMinor = 0,
  });

  final String purchaseOrderItemId;
  final int receivedQuantityMilli;
  final int unitCostMinor;
  final int freightCostMinor;
  final int dutyCostMinor;
  final int otherLandedCostMinor;
}

class GoodsReceiptDraft {
  const GoodsReceiptDraft({
    required this.stockLocationId,
    required this.lines,
    this.supplierDocumentNumber,
    this.notes,
    this.receivedAt,
    this.operationId,
  });

  final String stockLocationId;
  final List<GoodsReceiptLineDraft> lines;
  final String? supplierDocumentNumber;
  final String? notes;
  final DateTime? receivedAt;
  final String? operationId;
}

class GoodsReceiptLine {
  const GoodsReceiptLine({
    required this.id,
    required this.purchaseOrderItemId,
    required this.productId,
    required this.productName,
    required this.receivedQuantityMilli,
    required this.unitCostMinor,
    required this.freightCostMinor,
    required this.dutyCostMinor,
    required this.otherLandedCostMinor,
    required this.landedUnitCostMinor,
    required this.weightedAverageCostMinorAfter,
  });

  final String id;
  final String purchaseOrderItemId;
  final String productId;
  final String productName;
  final int receivedQuantityMilli;
  final int unitCostMinor;
  final int freightCostMinor;
  final int dutyCostMinor;
  final int otherLandedCostMinor;
  final int landedUnitCostMinor;
  final int weightedAverageCostMinorAfter;
}

class GoodsReceipt {
  const GoodsReceipt({
    required this.id,
    required this.receiptNumber,
    required this.stockLocationId,
    required this.stockLocationName,
    required this.receivedByUserId,
    required this.receivedAt,
    required this.lines,
    this.supplierDocumentNumber,
    this.notes,
  });

  final String id;
  final String receiptNumber;
  final String stockLocationId;
  final String stockLocationName;
  final String receivedByUserId;
  final DateTime receivedAt;
  final String? supplierDocumentNumber;
  final String? notes;
  final List<GoodsReceiptLine> lines;
}
