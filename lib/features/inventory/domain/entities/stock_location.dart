enum StockLocationType {
  salesFloor('sales_floor', 'Sales floor'),
  warehouse('warehouse', 'Warehouse'),
  returns('returns', 'Returns'),
  damaged('damaged', 'Damaged');

  const StockLocationType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static StockLocationType fromDatabase(String value) {
    return values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => StockLocationType.warehouse,
    );
  }
}

class StockLocation {
  const StockLocation({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.code,
    required this.name,
    required this.type,
    required this.isDefault,
    required this.isActive,
  });

  final String id;
  final String organizationId;
  final String branchId;
  final String code;
  final String name;
  final StockLocationType type;
  final bool isDefault;
  final bool isActive;
}

class StockLocationDraft {
  const StockLocationDraft({
    required this.code,
    required this.name,
    this.type = StockLocationType.warehouse,
    this.isDefault = false,
  });

  final String code;
  final String name;
  final StockLocationType type;
  final bool isDefault;
}
