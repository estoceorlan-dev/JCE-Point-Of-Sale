import 'product_price.dart';

class ProductDraft {
  const ProductDraft({
    required this.sku,
    required this.name,
    required this.unitId,
    required this.unitPriceMinor,
    this.categoryId,
    this.taxCategoryId,
    this.description,
    this.barcodes = const <String>[],
    this.imagePaths = const <String>[],
    this.priceBranchId,
    PriceScope? priceScope,
    this.priceEffectiveFrom,
  }) : priceScope =
           priceScope ??
           (priceBranchId == null
               ? PriceScope.organization
               : PriceScope.branch);

  final String sku;
  final String name;
  final String unitId;
  final String? categoryId;
  final String? taxCategoryId;
  final String? description;
  final List<String> barcodes;
  final List<String> imagePaths;
  final int unitPriceMinor;
  final PriceScope priceScope;
  final String? priceBranchId;
  final DateTime? priceEffectiveFrom;

  ProductPriceDraft get price => ProductPriceDraft(
    scope: priceScope,
    branchId: priceBranchId,
    unitPriceMinor: unitPriceMinor,
    effectiveFrom: priceEffectiveFrom,
  );

  ProductDraft normalized() {
    return ProductDraft(
      sku: sku.trim().toUpperCase(),
      name: name.trim(),
      unitId: unitId.trim(),
      categoryId: _nullIfBlank(categoryId),
      taxCategoryId: _nullIfBlank(taxCategoryId),
      description: _nullIfBlank(description),
      barcodes: barcodes
          .map((barcode) => barcode.trim())
          .where((barcode) => barcode.isNotEmpty)
          .toSet()
          .toList(growable: false),
      imagePaths: imagePaths
          .map((path) => path.trim())
          .where((path) => path.isNotEmpty)
          .toSet()
          .toList(growable: false),
      unitPriceMinor: unitPriceMinor,
      priceScope: priceScope,
      priceBranchId: _nullIfBlank(priceBranchId),
      priceEffectiveFrom: priceEffectiveFrom?.toUtc(),
    );
  }

  static String? _nullIfBlank(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
