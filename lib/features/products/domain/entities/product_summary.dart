class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.sku,
    required this.name,
    required this.unitName,
    required this.unitPriceMinor,
    required this.isActive,
    this.categoryName,
    this.primaryBarcode,
  });

  final String id;
  final String sku;
  final String name;
  final String? categoryName;
  final String unitName;
  final String? primaryBarcode;
  final int unitPriceMinor;
  final bool isActive;
}

class ProductPage {
  const ProductPage({required this.items, required this.hasMore});

  final List<ProductSummary> items;
  final bool hasMore;
}
