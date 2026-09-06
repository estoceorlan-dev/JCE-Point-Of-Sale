import 'product_price.dart';
import 'product_barcode_draft.dart';

class ProductDraft {
  const ProductDraft({
    required this.sku,
    required this.name,
    required this.unitId,
    required this.unitPriceMinor,
    this.categoryId,
    this.taxCategoryId,
    this.description,
    List<String> barcodes = const <String>[],
    List<ProductBarcodeDraft>? barcodeDrafts,
    this.imagePaths = const <String>[],
    this.priceBranchId,
    PriceScope? priceScope,
    this.priceEffectiveFrom,
    this.preserveBranchPrices = false,
  }) : _legacyBarcodes = barcodes,
       _barcodeDrafts = barcodeDrafts,
       priceScope =
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
  final List<String> _legacyBarcodes;
  final List<ProductBarcodeDraft>? _barcodeDrafts;

  List<ProductBarcodeDraft> get barcodeDrafts =>
      _barcodeDrafts ??
      [
        for (var index = 0; index < _legacyBarcodes.length; index++)
          ProductBarcodeDraft(
            value: _legacyBarcodes[index],
            isPrimary: index == 0,
          ),
      ];

  /// Legacy commands keep the primary barcode first for older clients.
  List<String> get barcodes => [
    ...barcodeDrafts
        .where((value) => value.isPrimary)
        .map((value) => value.value),
    ...barcodeDrafts
        .where((value) => !value.isPrimary)
        .map((value) => value.value),
  ];
  final List<String> imagePaths;
  final int unitPriceMinor;
  final PriceScope priceScope;
  final String? priceBranchId;
  final DateTime? priceEffectiveFrom;
  final bool preserveBranchPrices;

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
      barcodeDrafts: barcodeDrafts
          .map((value) => value.normalized())
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
      preserveBranchPrices: preserveBranchPrices,
    );
  }

  static String? _nullIfBlank(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
