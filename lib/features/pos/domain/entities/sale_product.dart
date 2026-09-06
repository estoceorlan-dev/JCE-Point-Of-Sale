class SaleProduct {
  const SaleProduct({
    required this.id,
    required this.sku,
    required this.name,
    required this.unitName,
    required this.stockLocationId,
    required this.stockLocationName,
    required this.unitPriceMinor,
    required this.unitCostMinor,
    required this.taxRateBasisPoints,
    required this.taxInclusive,
    required this.availableQuantityMilli,
    required this.inventoryVersion,
    this.primaryBarcode,
    this.barcodes = const [],
    this.categoryId,
  });

  final String id;
  final String sku;
  final String name;
  final String unitName;
  final String? primaryBarcode;
  final List<String> barcodes;
  final String? categoryId;
  final String stockLocationId;
  final String stockLocationName;
  final int unitPriceMinor;
  final int unitCostMinor;
  final int taxRateBasisPoints;
  final bool taxInclusive;
  final int availableQuantityMilli;
  final int inventoryVersion;
}
