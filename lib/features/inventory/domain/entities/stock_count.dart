enum StockCountType {
  full('full', 'Full count'),
  cycle('cycle', 'Cycle count');

  const StockCountType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static StockCountType fromDatabase(String value) {
    return values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => StockCountType.cycle,
    );
  }
}

enum StockCountStatus {
  inProgress('in_progress', 'In progress'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const StockCountStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static StockCountStatus fromDatabase(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => StockCountStatus.cancelled,
    );
  }
}

class StockCountItem {
  const StockCountItem({
    required this.id,
    required this.productId,
    required this.sku,
    required this.productName,
    required this.expectedQuantityMilli,
    required this.version,
    this.countedQuantityMilli,
    this.varianceQuantityMilli,
  });

  final String id;
  final String productId;
  final String sku;
  final String productName;
  final int expectedQuantityMilli;
  final int? countedQuantityMilli;
  final int? varianceQuantityMilli;
  final int version;
}

class StockCount {
  const StockCount({
    required this.id,
    required this.stockLocationId,
    required this.stockLocationName,
    required this.type,
    required this.status,
    required this.items,
    required this.startedAt,
    required this.version,
    this.notes,
    this.completedAt,
  });

  final String id;
  final String stockLocationId;
  final String stockLocationName;
  final StockCountType type;
  final StockCountStatus status;
  final List<StockCountItem> items;
  final DateTime startedAt;
  final int version;
  final String? notes;
  final DateTime? completedAt;

  bool get hasUncountedItems =>
      items.any((item) => item.countedQuantityMilli == null);
}

class StartStockCountDraft {
  const StartStockCountDraft({
    required this.stockLocationId,
    required this.type,
    this.productIds = const [],
    this.notes,
    this.operationId,
  });

  final String stockLocationId;
  final StockCountType type;
  final List<String> productIds;
  final String? notes;
  final String? operationId;
}
