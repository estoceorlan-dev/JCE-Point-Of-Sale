class InventoryBalance {
  const InventoryBalance({
    required this.id,
    required this.productId,
    required this.sku,
    required this.productName,
    required this.stockLocationId,
    required this.stockLocationName,
    required this.onHandMilli,
    required this.reservedMilli,
    required this.reorderPointMilli,
    required this.version,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final String sku;
  final String productName;
  final String stockLocationId;
  final String stockLocationName;
  final int onHandMilli;
  final int reservedMilli;
  final int reorderPointMilli;
  final int version;
  final DateTime updatedAt;

  int get availableMilli => onHandMilli - reservedMilli;
  bool get isLowStock => onHandMilli <= reorderPointMilli;
}

class InventoryBalanceQuery {
  const InventoryBalanceQuery({
    this.search = '',
    this.stockLocationId,
    this.lowStockOnly = false,
  });

  final String search;
  final String? stockLocationId;
  final bool lowStockOnly;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InventoryBalanceQuery &&
            other.search == search &&
            other.stockLocationId == stockLocationId &&
            other.lowStockOnly == lowStockOnly;
  }

  @override
  int get hashCode => Object.hash(search, stockLocationId, lowStockOnly);
}
