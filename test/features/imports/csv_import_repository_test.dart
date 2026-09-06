import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/features/imports/data/repositories/drift_csv_import_repository.dart';
import 'package:jce_pos/features/imports/domain/entities/csv_import.dart';
import 'package:jce_pos/features/inventory/data/data_sources/inventory_local_data_source.dart';
import 'package:jce_pos/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:jce_pos/features/products/data/data_sources/product_catalog_local_data_source.dart';
import 'package:jce_pos/features/products/data/repositories/drift_products_repository.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  late AppDatabase database;
  late DriftCsvImportRepository repository;
  final now = DateTime.utc(2026, 9, 6);
  const context = BusinessContext(
    organizationId: 'org',
    branchId: 'branch',
    actorUserId: 'admin',
  );

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final transaction = LocalMutationTransaction(database);
    final clock = FixedAppClock(now);
    repository = DriftCsvImportRepository(
      database: database,
      clock: clock,
      productsFactory: (ids) => DriftProductsRepository(
        localDataSource: ProductCatalogLocalDataSource(database),
        localMutationTransaction: transaction,
        idGenerator: ids,
        clock: clock,
      ),
      inventoryFactory: (ids) => DriftInventoryRepository(
        database: database,
        localDataSource: InventoryLocalDataSource(database),
        localMutationTransaction: transaction,
        idGenerator: ids,
        clock: clock,
      ),
    );
    await database
        .into(database.organizations)
        .insert(
          OrganizationsCompanion.insert(
            id: 'org',
            code: 'ORG',
            name: 'Organization',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.branches)
        .insert(
          BranchesCompanion.insert(
            id: 'branch',
            organizationId: 'org',
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
            organizationId: 'org',
            code: 'PC',
            name: 'Piece',
            abbreviation: 'pc',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.stockLocations)
        .insert(
          StockLocationsCompanion.insert(
            id: 'floor',
            organizationId: 'org',
            branchId: 'branch',
            code: 'FLOOR',
            name: 'Sales floor',
            isDefault: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(() => database.close());

  Future<CsvImportPreview> preview(
    String source, [
    CsvImportKind kind = CsvImportKind.catalog,
  ]) async {
    final result = await repository.preview(
      context: context,
      kind: kind,
      source: source,
    );
    expect(result.failureOrNull, isNull);
    return result.valueOrNull!;
  }

  test(
    'preview makes no writes; confirmation is atomic and idempotent',
    () async {
      final draft = await preview(
        'sku,name,unit_code,price,barcodes,primary_barcode\nAA,Milk,PC,112.50,48001|48002,48002\nBB,Tea,PC,50,,',
      );
      expect(draft.canConfirm, isTrue);
      expect(await database.select(database.products).get(), isEmpty);
      expect(await database.select(database.syncOutboxEntries).get(), isEmpty);
      final saved = await repository.confirm(context: context, preview: draft);
      expect(saved.failureOrNull, isNull);
      expect(saved.valueOrNull, 2);
      final audit = await database.select(database.localAuditLogs).get();
      final outbox = await database.select(database.syncOutboxEntries).get();
      expect(audit, hasLength(2));
      expect(outbox, hasLength(2));
      expect(
        outbox.map((row) => row.operationId).toSet(),
        audit.map((row) => row.operationId).toSet(),
      );
      final primary = await (database.select(
        database.productBarcodes,
      )..where((row) => row.isPrimary.equals(true))).getSingle();
      expect(primary.barcode, '48002');
      expect(
        (await repository.confirm(
          context: context,
          preview: draft,
        )).valueOrNull,
        0,
      );
      expect(await database.select(database.products).get(), hasLength(2));
    },
  );

  test(
    'a later row failure rolls back products, prices, audit and outbox',
    () async {
      final draft = await preview(
        'sku,name,unit_code,price\nGOOD,Milk,PC,20\nFAIL,Tea,PC,30',
      );
      await database.customStatement("""
      CREATE TRIGGER fail_import BEFORE INSERT ON products
      WHEN NEW.sku = 'FAIL' BEGIN SELECT RAISE(ABORT, 'Injected write failure'); END
    """);
      final saved = await repository.confirm(context: context, preview: draft);
      expect(saved.isSuccess, isFalse);
      expect(await database.select(database.products).get(), isEmpty);
      expect(await database.select(database.productPrices).get(), isEmpty);
      expect(await database.select(database.localAuditLogs).get(), isEmpty);
      expect(await database.select(database.syncOutboxEntries).get(), isEmpty);
    },
  );

  test(
    'conflicting barcodes and normalized duplicate SKUs block confirmation',
    () async {
      final draft = await preview(
        'sku,name,unit_code,price,barcodes\nAA,Milk,PC,20,480-01\nBB,Tea,PC,30,48001',
      );
      expect(draft.canConfirm, isFalse);
      expect(draft.rows.last.errors.join(), contains('repeated'));
      expect(
        (await repository.confirm(context: context, preview: draft)).isSuccess,
        isFalse,
      );
      final skus = await preview(
        'sku,name,unit_code,price\nA-1,Milk,PC,20\na-1,Tea,PC,30',
      );
      expect(skus.canConfirm, isFalse);
      expect(await database.select(database.products).get(), isEmpty);
    },
  );

  test(
    'catalog upsert appends organization price and keeps branch overrides',
    () async {
      final before = now.subtract(const Duration(days: 2));
      await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              id: 'product',
              organizationId: 'org',
              unitId: 'unit',
              sku: 'SKU-1',
              normalizedSku: 'SKU-1',
              name: 'Original',
              normalizedName: 'original',
              createdAt: before,
              updatedAt: before,
            ),
          );
      for (final scope in ['*', 'branch']) {
        await database
            .into(database.productPrices)
            .insert(
              ProductPricesCompanion.insert(
                id: scope,
                organizationId: 'org',
                productId: 'product',
                branchId: Value(scope == '*' ? null : scope),
                branchScope: scope,
                unitPriceMinor: scope == '*' ? 10000 : 12500,
                effectiveFrom: before,
                createdByUserId: 'admin',
                createdAt: before,
              ),
            );
      }
      final draft = await preview(
        'sku,name,unit_code,price\nsku-1,Renamed,PC,150',
      );
      expect(
        (await repository.confirm(context: context, preview: draft)).isSuccess,
        isTrue,
      );
      final prices = await database.select(database.productPrices).get();
      expect(prices, hasLength(3));
      expect(
        prices.singleWhere((row) => row.id == 'branch').effectiveTo,
        isNull,
      );
      expect(prices.singleWhere((row) => row.id == '*').effectiveTo, now);
      expect(
        prices
            .singleWhere((row) => row.id != '*' && row.id != 'branch')
            .unitPriceMinor,
        15000,
      );
      expect(
        (await database.select(database.products).getSingle()).name,
        'Renamed',
      );
    },
  );

  test('price-only changes after preview require a new preview', () async {
    final original = await preview('sku,name,unit_code,price\nAA,Milk,PC,20');
    await repository.confirm(context: context, preview: original);
    final edited = await preview('sku,name,unit_code,price\nAA,New name,PC,30');
    await database
        .update(database.productPrices)
        .write(const ProductPricesCompanion(unitPriceMinor: Value(2500)));
    final saved = await repository.confirm(context: context, preview: edited);
    expect(saved.failureOrNull, isA<ConflictFailure>());
  });

  test(
    'opening stock writes a ledger entry and cannot reset existing history',
    () async {
      final catalog = await preview('sku,name,unit_code,price\nAA,Milk,PC,20');
      await repository.confirm(context: context, preview: catalog);
      final stock = await preview(
        'sku,location_code,quantity\nAA,FLOOR,5',
        CsvImportKind.openingStock,
      );
      expect(stock.canConfirm, isTrue);
      final saved = await repository.confirm(context: context, preview: stock);
      expect(saved.failureOrNull, isNull);
      expect(
        (await database.select(database.inventoryBalances).getSingle())
            .onHandMilli,
        5000,
      );
      expect(
        await database.select(database.inventoryLedgerEntries).get(),
        hasLength(1),
      );
      final again = await preview(
        'sku,location_code,quantity\nAA,FLOOR,7',
        CsvImportKind.openingStock,
      );
      expect(again.canConfirm, isFalse);
      expect(again.rows.single.errors.join(), contains('ledger history'));
    },
  );

  test(
    'stock preview rejects unknown scope, fractional pieces and oversized quantities',
    () async {
      await repository.confirm(
        context: context,
        preview: await preview('sku,name,unit_code,price\nAA,Milk,PC,20'),
      );
      final stock = await preview(
        'sku,location_code,quantity\nAA,FLOOR,0.5\nAA,FOREIGN,9223372036854775807',
        CsvImportKind.openingStock,
      );
      expect(stock.canConfirm, isFalse);
      expect(stock.rows.first.errors.join(), contains('whole-unit'));
      expect(stock.rows.last.errors.length, greaterThanOrEqualTo(2));
    },
  );
}
