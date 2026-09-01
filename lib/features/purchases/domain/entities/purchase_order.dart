import 'goods_receipt.dart';

enum PurchaseOrderStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Awaiting approval'),
  approved('approved', 'Approved'),
  partiallyReceived('partially_received', 'Partially received'),
  received('received', 'Received'),
  cancelled('cancelled', 'Cancelled');

  const PurchaseOrderStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static PurchaseOrderStatus fromDatabase(String value) => values.firstWhere(
    (status) => status.databaseValue == value,
    orElse: () =>
        throw FormatException('Unknown purchase order status: $value'),
  );
}

class PurchaseOrderLineDraft {
  const PurchaseOrderLineDraft({
    required this.productId,
    required this.orderedQuantityMilli,
    required this.unitCostMinor,
    this.estimatedLandedCostMinor = 0,
  });

  final String productId;
  final int orderedQuantityMilli;
  final int unitCostMinor;
  final int estimatedLandedCostMinor;
}

class PurchaseOrderDraft {
  const PurchaseOrderDraft({
    required this.supplierId,
    required this.lines,
    this.expectedDeliveryAt,
    this.notes,
    this.operationId,
  });

  final String supplierId;
  final List<PurchaseOrderLineDraft> lines;
  final DateTime? expectedDeliveryAt;
  final String? notes;
  final String? operationId;
}

class PurchaseProductOption {
  const PurchaseProductOption({
    required this.id,
    required this.sku,
    required this.name,
  });

  final String id;
  final String sku;
  final String name;
}

class ReceivingLocationOption {
  const ReceivingLocationOption({required this.id, required this.name});

  final String id;
  final String name;
}

class PurchaseOptions {
  const PurchaseOptions({
    required this.suppliers,
    required this.products,
    required this.locations,
  });

  final List<({String id, String code, String name})> suppliers;
  final List<PurchaseProductOption> products;
  final List<ReceivingLocationOption> locations;
}

class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.id,
    required this.productId,
    required this.sku,
    required this.productName,
    required this.orderedQuantityMilli,
    required this.receivedQuantityMilli,
    required this.cancelledQuantityMilli,
    required this.unitCostMinor,
    required this.estimatedLandedCostMinor,
    required this.version,
  });

  final String id;
  final String productId;
  final String sku;
  final String productName;
  final int orderedQuantityMilli;
  final int receivedQuantityMilli;
  final int cancelledQuantityMilli;
  final int unitCostMinor;
  final int estimatedLandedCostMinor;
  final int version;

  int get remainingQuantityMilli =>
      orderedQuantityMilli - receivedQuantityMilli - cancelledQuantityMilli;
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.orderNumber,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.createdByUserId,
    required this.version,
    required this.lines,
    required this.receipts,
    required this.createdAt,
    required this.updatedAt,
    this.approvedByUserId,
    this.notes,
    this.expectedDeliveryAt,
    this.cancellationReason,
  });

  final String id;
  final String orderNumber;
  final String supplierId;
  final String supplierName;
  final PurchaseOrderStatus status;
  final String createdByUserId;
  final String? approvedByUserId;
  final String? notes;
  final DateTime? expectedDeliveryAt;
  final String? cancellationReason;
  final int version;
  final List<PurchaseOrderLine> lines;
  final List<GoodsReceipt> receipts;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalOrderedQuantityMilli =>
      lines.fold(0, (total, line) => total + line.orderedQuantityMilli);

  int get totalReceivedQuantityMilli =>
      lines.fold(0, (total, line) => total + line.receivedQuantityMilli);

  int get totalRemainingQuantityMilli =>
      lines.fold(0, (total, line) => total + line.remainingQuantityMilli);

  int get totalMinor => lines.fold(
    0,
    (total, line) =>
        total +
        ((line.orderedQuantityMilli * line.unitCostMinor + 500) ~/ 1000),
  );
}
