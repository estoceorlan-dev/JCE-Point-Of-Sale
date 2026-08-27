import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/products/data/data_sources/product_catalog_local_data_source.dart';
import 'package:jce_pos/features/products/data/repositories/drift_products_repository.dart';
import 'package:jce_pos/features/products/domain/entities/catalog_drafts.dart';
import 'package:jce_pos/features/products/domain/entities/product_draft.dart';
import 'package:jce_pos/features/products/domain/entities/product_price.dart';
import 'package:jce_pos/features/products/domain/entities/product_query.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  late AppDatabase database;
  late _MutableClock clock;
  late DriftProductsRepository repository;

  const context = BusinessContext(
    organizationId: 'organization',
    branchId: 'branch',
    actorUserId: 'user',
  );

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _MutableClock(DateTime.utc(2026, 6, 28, 8));
    repository = DriftProductsRepository(
      localDataSource: ProductCatalogLocalDataSource(database),
      localMutationTransaction: LocalMutationTransaction(database),
      idGenerator: _SequenceIdGenerator(),
      clock: clock,
    );
    await _seedContext(database);
  });

  tearDown(() => database.close());

  test('duplicate SKU is rejected within an organization', () async {
    expect(
      (await repository.createProduct(
        context: context,
        draft: _draft(sku: 'SKU-001'),
      )).isSuccess,
      isTrue,
    );

    final duplicate = await repository.createProduct(
      context: context,
      draft: _draft(sku: ' sku-001 ', name: 'Another product'),
    );

    expect(duplicate.failureOrNull, isA<ConflictFailure>());
  });

  test('duplicate barcode is rejected across products', () async {
    await repository.createProduct(
      context: context,
      draft: _draft(sku: 'SKU-001', barcodes: const ['4800-1234']),
    );

    final duplicate = await repository.createProduct(
      context: context,
      draft: _draft(
        sku: 'SKU-002',
        name: 'Another product',
        barcodes: const ['48001234'],
      ),
    );

    expect(duplicate.failureOrNull, isA<ConflictFailure>());
  });

  test('product search works from local Drift data while offline', () async {
    await repository.createProduct(
      context: context,
      draft: _draft(
        sku: 'COF-100',
        name: 'Premium Coffee',
        barcodes: const ['12345678'],
      ),
    );
    await repository.createProduct(
      context: context,
      draft: _draft(sku: 'TEA-100', name: 'Green Tea'),
    );

    final byName = await repository
        .watchProducts(
          context: context,
          query: const ProductQuery(search: 'coffee'),
        )
        .first;
    final byBarcode = await repository
        .watchProducts(
          context: context,
          query: const ProductQuery(search: '1234-5678'),
        )
        .first;

    expect(byName.items.map((item) => item.sku), ['COF-100']);
    expect(byBarcode.items.map((item) => item.sku), ['COF-100']);
  });

  test('branch-specific price overrides the organization price', () async {
    final created = await repository.createProduct(
      context: context,
      draft: _draft(sku: 'SKU-001', unitPriceMinor: 10000),
    );
    clock.value = DateTime.utc(2026, 6, 28, 9);
    await repository.updateProduct(
      context: context,
      productId: created.valueOrNull!,
      draft: _draft(
        sku: 'SKU-001',
        unitPriceMinor: 12500,
        priceBranchId: 'branch',
      ),
    );

    final page = await repository
        .watchProducts(context: context, query: const ProductQuery())
        .first;

    expect(page.items.single.unitPriceMinor, 12500);
  });

  test('metadata-only edits do not append duplicate prices', () async {
    final created = await repository.createProduct(
      context: context,
      draft: _draft(sku: 'SKU-001', unitPriceMinor: 10000),
    );
    clock.value = DateTime.utc(2026, 6, 28, 9);

    final updated = await repository.updateProduct(
      context: context,
      productId: created.valueOrNull!,
      draft: _draft(
        sku: 'SKU-001',
        name: 'Renamed Product',
        unitPriceMinor: 10000,
      ),
    );

    expect(updated.isSuccess, isTrue);
    expect(await database.select(database.productPrices).get(), hasLength(1));
  });

  test('editing a branch-priced product preserves its price scope', () async {
    final created = await repository.createProduct(
      context: context,
      draft: _draft(sku: 'SKU-001', unitPriceMinor: 10000),
    );
    clock.value = DateTime.utc(2026, 6, 28, 9);
    await repository.updateProduct(
      context: context,
      productId: created.valueOrNull!,
      draft: _draft(
        sku: 'SKU-001',
        unitPriceMinor: 12500,
        priceScope: PriceScope.branch,
        priceBranchId: 'branch',
      ),
    );
    clock.value = DateTime.utc(2026, 6, 28, 10);

    await repository.updateProduct(
      context: context,
      productId: created.valueOrNull!,
      draft: _draft(
        sku: 'SKU-001',
        name: 'Branch Product',
        unitPriceMinor: 12500,
        priceScope: PriceScope.branch,
        priceBranchId: 'branch',
      ),
    );

    final prices = await database.select(database.productPrices).get();
    final product = await repository.getProduct(
      context: context,
      productId: created.valueOrNull!,
    );
    expect(prices, hasLength(2));
    expect(product?.activePrice?.scope, PriceScope.branch);
    expect(product?.activePrice?.branchId, 'branch');
  });

  test('branch pricing can transition back to organization pricing', () async {
    final created = await repository.createProduct(
      context: context,
      draft: _draft(sku: 'SKU-001', unitPriceMinor: 10000),
    );
    clock.value = DateTime.utc(2026, 6, 28, 9);
    await repository.updateProduct(
      context: context,
      productId: created.valueOrNull!,
      draft: _draft(
        sku: 'SKU-001',
        unitPriceMinor: 12500,
        priceScope: PriceScope.branch,
        priceBranchId: 'branch',
      ),
    );
    clock.value = DateTime.utc(2026, 6, 28, 10);

    await repository.updateProduct(
      context: context,
      productId: created.valueOrNull!,
      draft: _draft(
        sku: 'SKU-001',
        unitPriceMinor: 15000,
        priceScope: PriceScope.organization,
      ),
    );

    final product = await repository.getProduct(
      context: context,
      productId: created.valueOrNull!,
    );
    final branchPrices = await (database.select(
      database.productPrices,
    )..where((row) => row.branchId.equals('branch'))).get();
    expect(product?.activePrice?.scope, PriceScope.organization);
    expect(product?.activePrice?.unitPriceMinor, 15000);
    expect(branchPrices.single.effectiveTo, clock.value);
  });

  test(
    'explicit price history writes its own audit and outbox operation',
    () async {
      final created = await repository.createProduct(
        context: context,
        draft: _draft(sku: 'SKU-001', unitPriceMinor: 10000),
      );
      clock.value = DateTime.utc(2026, 6, 28, 9);

      final price = await repository.addProductPrice(
        context: context,
        productId: created.valueOrNull!,
        draft: const ProductPriceDraft(
          scope: PriceScope.branch,
          branchId: 'branch',
          unitPriceMinor: 12500,
        ),
      );

      final outbox = await database.select(database.syncOutboxEntries).get();
      final audits = await database.select(database.localAuditLogs).get();
      final priceCommand = outbox.singleWhere(
        (entry) => entry.commandType == 'product_price.create',
      );
      expect(price.isSuccess, isTrue);
      expect(outbox, hasLength(2));
      expect(
        audits.any((entry) => entry.operationId == priceCommand.operationId),
        isTrue,
      );
    },
  );

  test('product edits preserve the selected tax category', () async {
    final now = DateTime.utc(2026, 6, 28);
    await database
        .into(database.taxCategories)
        .insert(
          TaxCategoriesCompanion.insert(
            id: 'vat',
            organizationId: 'organization',
            code: 'VAT12',
            name: 'VAT 12%',
            rateBasisPoints: 1200,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final created = await repository.createProduct(
      context: context,
      draft: _draft(sku: 'SKU-001', taxCategoryId: 'vat'),
    );
    clock.value = DateTime.utc(2026, 6, 28, 9);

    await repository.updateProduct(
      context: context,
      productId: created.valueOrNull!,
      draft: _draft(
        sku: 'SKU-001',
        name: 'Renamed Product',
        taxCategoryId: 'vat',
      ),
    );

    final product = await repository.getProduct(
      context: context,
      productId: created.valueOrNull!,
    );
    expect(product?.taxCategoryId, 'vat');
  });

  test(
    'archived products remain available for historical references',
    () async {
      final created = await repository.createProduct(
        context: context,
        draft: _draft(sku: 'SKU-001'),
      );
      await repository.setProductArchived(
        context: context,
        productId: created.valueOrNull!,
        archived: true,
      );

      final activePage = await repository
          .watchProducts(context: context, query: const ProductQuery())
          .first;
      final archivePage = await repository
          .watchProducts(
            context: context,
            query: const ProductQuery(includeArchived: true),
          )
          .first;
      final historicalProduct = await repository.getProduct(
        context: context,
        productId: created.valueOrNull!,
      );

      expect(activePage.items, isEmpty);
      expect(archivePage.items.single.isActive, isFalse);
      expect(historicalProduct, isA<Object>());
    },
  );

  test('product creation creates exactly one outbox operation', () async {
    await repository.createProduct(
      context: context,
      draft: _draft(
        sku: 'SKU-001',
        barcodes: const ['12345678', '87654321'],
        imagePaths: const ['C:/products/sku-001.jpg'],
      ),
    );

    final outboxRows = await database.select(database.syncOutboxEntries).get();
    final auditRows = await database.select(database.localAuditLogs).get();

    expect(outboxRows, hasLength(1));
    expect(outboxRows.single.commandType, 'product.create');
    expect(auditRows, hasLength(1));
    expect(auditRows.single.operationId, outboxRows.single.operationId);
  });

  test(
    'cross-organization product references are rejected atomically',
    () async {
      final now = DateTime.utc(2026, 6, 28);
      await database
          .into(database.organizations)
          .insert(
            OrganizationsCompanion.insert(
              id: 'other-organization',
              code: 'OTHER',
              name: 'Other Organization',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.units)
          .insert(
            UnitsCompanion.insert(
              id: 'other-unit',
              organizationId: 'other-organization',
              code: 'BOX',
              name: 'Box',
              abbreviation: 'box',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final result = await repository.createProduct(
        context: context,
        draft: ProductDraft(
          sku: 'SKU-FOREIGN',
          name: 'Invalid Product',
          unitId: 'other-unit',
          unitPriceMinor: 100,
        ),
      );

      expect(result.failureOrNull, isA<AuthorizationFailure>());
      expect(await database.select(database.products).get(), isEmpty);
      expect(await database.select(database.syncOutboxEntries).get(), isEmpty);
      expect(await database.select(database.localAuditLogs).get(), isEmpty);
    },
  );

  test('categories support update, archive, and restore', () async {
    final created = await repository.createCategory(
      context: context,
      draft: const CategoryDraft(name: 'Beverages'),
    );
    final categoryId = created.valueOrNull!;

    expect(
      (await repository.updateCategory(
        context: context,
        categoryId: categoryId,
        draft: const CategoryDraft(name: 'Hot Beverages'),
      )).isSuccess,
      isTrue,
    );
    await repository.setCategoryArchived(
      context: context,
      categoryId: categoryId,
      archived: true,
    );
    final archived = await repository
        .watchCategories(context: context, includeArchived: true)
        .first;
    expect(archived.single.name, 'Hot Beverages');
    expect(archived.single.isActive, isFalse);

    await repository.setCategoryArchived(
      context: context,
      categoryId: categoryId,
      archived: false,
    );
    final restored = await repository.watchCategories(context: context).first;
    expect(restored.single.isActive, isTrue);
  });

  test('units support update, archive, and restore', () async {
    final created = await repository.createUnit(
      context: context,
      draft: const UnitDraft(
        code: 'KG',
        name: 'Kilogram',
        abbreviation: 'kg',
        allowsFractional: true,
      ),
    );
    final unitId = created.valueOrNull!;

    await repository.updateUnit(
      context: context,
      unitId: unitId,
      draft: const UnitDraft(
        code: 'KGM',
        name: 'Kilogram Unit',
        abbreviation: 'kg',
        allowsFractional: true,
      ),
    );
    await repository.setUnitArchived(
      context: context,
      unitId: unitId,
      archived: true,
    );
    final archived = await repository
        .watchUnits(context: context, includeArchived: true)
        .first;
    final archivedUnit = archived.singleWhere((unit) => unit.id == unitId);
    expect(archivedUnit.code, 'KGM');
    expect(archivedUnit.isActive, isFalse);

    await repository.setUnitArchived(
      context: context,
      unitId: unitId,
      archived: false,
    );
    final restored = await repository.watchUnits(context: context).first;
    expect(restored.singleWhere((unit) => unit.id == unitId).isActive, isTrue);
  });

  test(
    'archived units preserve history but cannot be newly selected',
    () async {
      final created = await repository.createProduct(
        context: context,
        draft: _draft(sku: 'SKU-001'),
      );
      await repository.setUnitArchived(
        context: context,
        unitId: 'unit',
        archived: true,
      );

      final historical = await repository.getProduct(
        context: context,
        productId: created.valueOrNull!,
      );
      final newProduct = await repository.createProduct(
        context: context,
        draft: _draft(sku: 'SKU-002'),
      );

      expect(historical?.unitId, 'unit');
      expect(newProduct.failureOrNull, isA<AuthorizationFailure>());
    },
  );
}

ProductDraft _draft({
  required String sku,
  String name = 'Sample Product',
  List<String> barcodes = const [],
  List<String> imagePaths = const [],
  int unitPriceMinor = 10000,
  String? priceBranchId,
  PriceScope? priceScope,
  String? taxCategoryId,
}) {
  return ProductDraft(
    sku: sku,
    name: name,
    unitId: 'unit',
    barcodes: barcodes,
    imagePaths: imagePaths,
    unitPriceMinor: unitPriceMinor,
    taxCategoryId: taxCategoryId,
    priceScope: priceScope,
    priceBranchId: priceBranchId,
  ).normalized();
}

Future<void> _seedContext(AppDatabase database) async {
  final now = DateTime.utc(2026, 6, 28);
  await database
      .into(database.organizations)
      .insert(
        OrganizationsCompanion.insert(
          id: 'organization',
          code: 'JCE',
          name: 'JCE',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.branches)
      .insert(
        BranchesCompanion.insert(
          id: 'branch',
          organizationId: 'organization',
          code: 'MAIN',
          name: 'Main',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.units)
      .insert(
        UnitsCompanion.insert(
          id: 'unit',
          organizationId: 'organization',
          code: 'PC',
          name: 'Piece',
          abbreviation: 'pc',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

class _SequenceIdGenerator implements IdGenerator {
  var _value = 0;

  @override
  String newId() => 'id-${_value++}';
}

class _MutableClock implements AppClock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value.toUtc();
}
