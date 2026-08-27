import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/catalog_category.dart';
import '../../domain/entities/catalog_tax_category.dart';
import '../../domain/entities/catalog_unit.dart';
import '../../domain/entities/product.dart' as domain;
import '../../domain/entities/product_price.dart' as domain_price;
import '../../domain/entities/product_query.dart';
import '../../domain/entities/product_summary.dart';
import '../../domain/value_objects/catalog_normalizer.dart';

class ProductCatalogLocalDataSource {
  const ProductCatalogLocalDataSource(this._database);

  final AppDatabase _database;

  Stream<ProductPage> watchProducts({
    required String organizationId,
    required String branchId,
    required ProductQuery query,
    required DateTime now,
  }) {
    final normalizedSearch = CatalogNormalizer.search(query.search);
    final clauses = <String>[
      'p.organization_id = ?',
      if (!query.includeArchived) 'p.deleted_at IS NULL',
      if (query.categoryId != null) 'p.category_id = ?',
      if (normalizedSearch.isNotEmpty)
        '(p.normalized_name LIKE ? OR p.normalized_sku LIKE ? OR EXISTS ('
            'SELECT 1 FROM product_barcodes search_barcode '
            'WHERE search_barcode.product_id = p.id '
            'AND search_barcode.deleted_at IS NULL '
            'AND search_barcode.normalized_barcode LIKE ?))',
    ];
    final variables = <Variable<Object>>[
      Variable<String>(branchId),
      Variable<DateTime>(now.toUtc()),
      Variable<DateTime>(now.toUtc()),
      Variable<DateTime>(now.toUtc()),
      Variable<DateTime>(now.toUtc()),
      Variable<String>(organizationId),
      if (query.categoryId != null) Variable<String>(query.categoryId!),
      if (normalizedSearch.isNotEmpty) ...[
        Variable<String>('%$normalizedSearch%'),
        Variable<String>('%${CatalogNormalizer.sku(normalizedSearch)}%'),
        Variable<String>('%${CatalogNormalizer.barcode(normalizedSearch)}%'),
      ],
      Variable<int>(query.pageSize + 1),
      Variable<int>(query.offset),
    ];
    final statement =
        '''
SELECT
  p.id,
  p.sku,
  p.name,
  p.is_active,
  c.name AS category_name,
  u.name AS unit_name,
  (
    SELECT pb.barcode
    FROM product_barcodes pb
    WHERE pb.product_id = p.id AND pb.deleted_at IS NULL
    ORDER BY pb.is_primary DESC, pb.created_at ASC
    LIMIT 1
  ) AS primary_barcode,
  COALESCE(
    (
      SELECT branch_price.unit_price_minor
      FROM product_prices branch_price
      WHERE branch_price.product_id = p.id
        AND branch_price.branch_id = ?
        AND branch_price.effective_from <= ?
        AND (branch_price.effective_to IS NULL OR branch_price.effective_to > ?)
      ORDER BY branch_price.effective_from DESC
      LIMIT 1
    ),
    (
      SELECT global_price.unit_price_minor
      FROM product_prices global_price
      WHERE global_price.product_id = p.id
        AND global_price.branch_id IS NULL
        AND global_price.effective_from <= ?
        AND (global_price.effective_to IS NULL OR global_price.effective_to > ?)
      ORDER BY global_price.effective_from DESC
      LIMIT 1
    ),
    0
  ) AS unit_price_minor
FROM products p
JOIN units u ON u.id = p.unit_id
LEFT JOIN categories c ON c.id = p.category_id
WHERE ${clauses.join(' AND ')}
ORDER BY p.normalized_name ASC, p.normalized_sku ASC
LIMIT ? OFFSET ?
''';

    return _database
        .customSelect(
          statement,
          variables: variables,
          readsFrom: {
            _database.products,
            _database.categories,
            _database.units,
            _database.productBarcodes,
            _database.productPrices,
          },
        )
        .watch()
        .map((rows) {
          final hasMore = rows.length > query.pageSize;
          final visibleRows = hasMore ? rows.take(query.pageSize) : rows;
          return ProductPage(
            items: visibleRows
                .map(
                  (row) => ProductSummary(
                    id: row.read<String>('id'),
                    sku: row.read<String>('sku'),
                    name: row.read<String>('name'),
                    categoryName: row.readNullable<String>('category_name'),
                    unitName: row.read<String>('unit_name'),
                    primaryBarcode: row.readNullable<String>('primary_barcode'),
                    unitPriceMinor: row.read<int>('unit_price_minor'),
                    isActive: row.read<bool>('is_active'),
                  ),
                )
                .toList(growable: false),
            hasMore: hasMore,
          );
        });
  }

  Stream<List<CatalogCategory>> watchCategories({
    required String organizationId,
    required bool includeArchived,
  }) {
    final query = _database.select(_database.categories)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            (includeArchived ? const Constant(true) : row.deletedAt.isNull()),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.normalizedName)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => CatalogCategory(
              id: row.id,
              name: row.name,
              isActive: row.isActive,
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<List<CatalogUnit>> watchUnits({
    required String organizationId,
    required bool includeArchived,
  }) {
    final query = _database.select(_database.units)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            (includeArchived ? const Constant(true) : row.deletedAt.isNull()),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.name)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => CatalogUnit(
              id: row.id,
              code: row.code,
              name: row.name,
              abbreviation: row.abbreviation,
              allowsFractional: row.allowsFractional,
              isActive: row.isActive,
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<List<CatalogTaxCategory>> watchTaxCategories({
    required String organizationId,
    required bool includeArchived,
  }) {
    final query = _database.select(_database.taxCategories)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            (includeArchived ? const Constant(true) : row.deletedAt.isNull()),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.name)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => CatalogTaxCategory(
              id: row.id,
              code: row.code,
              name: row.name,
              rateBasisPoints: row.rateBasisPoints,
              isInclusive: row.isInclusive,
              isActive: row.isActive,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<domain.Product?> getProduct({
    required String organizationId,
    required String branchId,
    required String productId,
    required DateTime now,
  }) async {
    final row =
        await (_database.select(_database.products)..where(
              (product) =>
                  product.id.equals(productId) &
                  product.organizationId.equals(organizationId),
            ))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }
    final barcodes =
        await (_database.select(_database.productBarcodes)..where(
              (barcode) =>
                  barcode.productId.equals(productId) &
                  barcode.deletedAt.isNull(),
            ))
            .get();
    final images =
        await (_database.select(_database.productImages)..where(
              (image) =>
                  image.productId.equals(productId) & image.deletedAt.isNull(),
            ))
            .get();
    final priceRow = await _database
        .customSelect(
          '''
SELECT id, branch_id, unit_price_minor, effective_from, effective_to
FROM product_prices
WHERE organization_id = ?
  AND product_id = ?
  AND (branch_id = ? OR branch_id IS NULL)
  AND effective_from <= ?
  AND (effective_to IS NULL OR effective_to > ?)
ORDER BY CASE WHEN branch_id = ? THEN 0 ELSE 1 END,
         effective_from DESC
LIMIT 1
''',
          variables: [
            Variable<String>(organizationId),
            Variable<String>(productId),
            Variable<String>(branchId),
            Variable<DateTime>(now.toUtc()),
            Variable<DateTime>(now.toUtc()),
            Variable<String>(branchId),
          ],
          readsFrom: {_database.productPrices},
        )
        .getSingleOrNull();
    return domain.Product(
      id: row.id,
      organizationId: row.organizationId,
      sku: row.sku,
      name: row.name,
      unitId: row.unitId,
      categoryId: row.categoryId,
      taxCategoryId: row.taxCategoryId,
      description: row.description,
      barcodes: barcodes
          .map((barcode) => barcode.barcode)
          .toList(growable: false),
      imagePaths: images
          .map((image) => image.localPath)
          .whereType<String>()
          .toList(growable: false),
      activePrice: priceRow == null
          ? null
          : domain_price.ProductPrice(
              id: priceRow.read<String>('id'),
              scope: domain_price.PriceScope.fromBranchId(
                priceRow.readNullable<String>('branch_id'),
              ),
              branchId: priceRow.readNullable<String>('branch_id'),
              unitPriceMinor: priceRow.read<int>('unit_price_minor'),
              effectiveFrom: priceRow.read<DateTime>('effective_from'),
              effectiveTo: priceRow.readNullable<DateTime>('effective_to'),
            ),
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<bool> skuExists({
    required String organizationId,
    required String normalizedSku,
    String? excludingProductId,
  }) async {
    final query = _database.select(_database.products)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            row.normalizedSku.equals(normalizedSku) &
            (excludingProductId == null
                ? const Constant(true)
                : row.id.equals(excludingProductId).not()),
      )
      ..limit(1);
    return (await query.getSingleOrNull()) != null;
  }

  Future<bool> barcodeExists({
    required String organizationId,
    required List<String> normalizedBarcodes,
    String? excludingProductId,
  }) async {
    if (normalizedBarcodes.isEmpty) {
      return false;
    }
    final query = _database.select(_database.productBarcodes)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            row.normalizedBarcode.isIn(normalizedBarcodes) &
            row.deletedAt.isNull() &
            (excludingProductId == null
                ? const Constant(true)
                : row.productId.equals(excludingProductId).not()),
      )
      ..limit(1);
    return (await query.getSingleOrNull()) != null;
  }

  Future<bool> categoryNameExists({
    required String organizationId,
    required String normalizedName,
    String? excludingCategoryId,
  }) async {
    final query = _database.select(_database.categories)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            row.normalizedName.equals(normalizedName) &
            (excludingCategoryId == null
                ? const Constant(true)
                : row.id.equals(excludingCategoryId).not()),
      )
      ..limit(1);
    return (await query.getSingleOrNull()) != null;
  }

  Future<bool> unitCodeExists({
    required String organizationId,
    required String code,
    String? excludingUnitId,
  }) async {
    final query = _database.select(_database.units)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            row.code.equals(code) &
            (excludingUnitId == null
                ? const Constant(true)
                : row.id.equals(excludingUnitId).not()),
      )
      ..limit(1);
    return (await query.getSingleOrNull()) != null;
  }
}
