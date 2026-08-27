import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/catalog_category.dart';
import '../entities/catalog_drafts.dart';
import '../entities/catalog_tax_category.dart';
import '../entities/catalog_unit.dart';
import '../entities/product.dart';
import '../entities/product_draft.dart';
import '../entities/product_query.dart';
import '../entities/product_price.dart';
import '../entities/product_summary.dart';

abstract interface class ProductsRepository {
  Stream<ProductPage> watchProducts({
    required BusinessContext context,
    required ProductQuery query,
  });

  Stream<List<CatalogCategory>> watchCategories({
    required BusinessContext context,
    bool includeArchived = false,
  });

  Stream<List<CatalogUnit>> watchUnits({
    required BusinessContext context,
    bool includeArchived = false,
  });

  Stream<List<CatalogTaxCategory>> watchTaxCategories({
    required BusinessContext context,
    bool includeArchived = false,
  });

  Future<Product?> getProduct({
    required BusinessContext context,
    required String productId,
  });

  Future<Result<String, Failure>> createProduct({
    required BusinessContext context,
    required ProductDraft draft,
  });

  Future<Result<void, Failure>> updateProduct({
    required BusinessContext context,
    required String productId,
    required ProductDraft draft,
  });

  Future<Result<String, Failure>> addProductPrice({
    required BusinessContext context,
    required String productId,
    required ProductPriceDraft draft,
  });

  Future<Result<void, Failure>> setProductArchived({
    required BusinessContext context,
    required String productId,
    required bool archived,
  });

  Future<Result<String, Failure>> createCategory({
    required BusinessContext context,
    required CategoryDraft draft,
  });

  Future<Result<void, Failure>> updateCategory({
    required BusinessContext context,
    required String categoryId,
    required CategoryDraft draft,
  });

  Future<Result<void, Failure>> setCategoryArchived({
    required BusinessContext context,
    required String categoryId,
    required bool archived,
  });

  Future<Result<String, Failure>> createUnit({
    required BusinessContext context,
    required UnitDraft draft,
  });

  Future<Result<void, Failure>> updateUnit({
    required BusinessContext context,
    required String unitId,
    required UnitDraft draft,
  });

  Future<Result<void, Failure>> setUnitArchived({
    required BusinessContext context,
    required String unitId,
    required bool archived,
  });
}
