import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../entities/product_draft.dart';
import '../entities/product_price.dart';
import '../value_objects/catalog_normalizer.dart';

class ValidateProductUseCase {
  const ValidateProductUseCase();

  Result<ProductDraft, Failure> call(ProductDraft draft) {
    final value = draft.normalized();
    if (value.barcodeDrafts.isNotEmpty &&
        value.barcodeDrafts.where((barcode) => barcode.isPrimary).length != 1) {
      return const Result.failure(
        ValidationFailure('Choose exactly one primary barcode.'),
      );
    }
    if (value.sku.length < 2 || value.sku.length > 64) {
      return const Result.failure(
        ValidationFailure('SKU must contain between 2 and 64 characters.'),
      );
    }
    if (value.name.length < 2 || value.name.length > 160) {
      return const Result.failure(
        ValidationFailure(
          'Product name must contain between 2 and 160 characters.',
        ),
      );
    }
    if (value.unitId.isEmpty) {
      return const Result.failure(ValidationFailure('A unit is required.'));
    }
    if (value.unitPriceMinor < 0) {
      return const Result.failure(
        ValidationFailure('Unit price cannot be negative.'),
      );
    }
    if (value.priceScope == PriceScope.organization &&
        value.priceBranchId != null) {
      return const Result.failure(
        ValidationFailure('Organization pricing cannot target a branch.'),
      );
    }
    if (value.priceScope == PriceScope.branch && value.priceBranchId == null) {
      return const Result.failure(
        ValidationFailure('Branch pricing requires a branch.'),
      );
    }
    if (value.barcodes.any((barcode) {
      final normalized = CatalogNormalizer.barcode(barcode);
      return normalized.length < 4 || normalized.length > 64;
    })) {
      return const Result.failure(
        ValidationFailure(
          'Each barcode must contain between 4 and 64 characters.',
        ),
      );
    }
    final normalizedBarcodes = value.barcodes
        .map(CatalogNormalizer.barcode)
        .toList(growable: false);
    if (normalizedBarcodes.toSet().length != normalizedBarcodes.length) {
      return const Result.failure(
        ValidationFailure('A product cannot contain duplicate barcodes.'),
      );
    }
    return Result.success(value);
  }
}
