import 'inventory_transaction_type.dart';

class InventoryMovementLineDraft {
  const InventoryMovementLineDraft({
    required this.stockLocationId,
    required this.productId,
    required this.quantityDeltaMilli,
    this.expectedBalanceVersion,
  });

  final String stockLocationId;
  final String productId;
  final int quantityDeltaMilli;
  final int? expectedBalanceVersion;
}

class InventoryMovementDraft {
  const InventoryMovementDraft({
    required this.type,
    required this.lines,
    this.operationId,
    this.reasonCode,
    this.notes,
    this.referenceType,
    this.referenceId,
    this.reversesTransactionId,
    this.approvedByUserId,
    this.occurredAt,
  });

  final InventoryTransactionType type;
  final List<InventoryMovementLineDraft> lines;
  final String? operationId;
  final String? reasonCode;
  final String? notes;
  final String? referenceType;
  final String? referenceId;
  final String? reversesTransactionId;
  final String? approvedByUserId;
  final DateTime? occurredAt;
}

class InventoryMovementLine {
  const InventoryMovementLine({
    required this.id,
    required this.stockLocationId,
    required this.stockLocationName,
    required this.productId,
    required this.sku,
    required this.productName,
    required this.quantityDeltaMilli,
    required this.balanceAfterMilli,
  });

  final String id;
  final String stockLocationId;
  final String stockLocationName;
  final String productId;
  final String sku;
  final String productName;
  final int quantityDeltaMilli;
  final int balanceAfterMilli;
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.operationId,
    required this.type,
    required this.status,
    required this.lines,
    required this.createdByUserId,
    required this.occurredAt,
    this.reasonCode,
    this.notes,
    this.referenceType,
    this.referenceId,
    this.reversesTransactionId,
    this.approvedByUserId,
  });

  final String id;
  final String operationId;
  final InventoryTransactionType type;
  final String status;
  final List<InventoryMovementLine> lines;
  final String createdByUserId;
  final DateTime occurredAt;
  final String? reasonCode;
  final String? notes;
  final String? referenceType;
  final String? referenceId;
  final String? reversesTransactionId;
  final String? approvedByUserId;
}

class InventoryMovementFilter {
  const InventoryMovementFilter({
    this.productId,
    this.stockLocationId,
    this.type,
    this.from,
    this.to,
    this.limit = 100,
  });

  final String? productId;
  final String? stockLocationId;
  final InventoryTransactionType? type;
  final DateTime? from;
  final DateTime? to;
  final int limit;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InventoryMovementFilter &&
            other.productId == productId &&
            other.stockLocationId == stockLocationId &&
            other.type == type &&
            other.from == from &&
            other.to == to &&
            other.limit == limit;
  }

  @override
  int get hashCode =>
      Object.hash(productId, stockLocationId, type, from, to, limit);
}
