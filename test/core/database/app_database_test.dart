import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/database_health_check_service.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('creates the complete current schema on a fresh database', () async {
    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();

    expect(
      rows.map((row) => row.read<String>('name')),
      containsAll(<String>[
        'app_users',
        'approval_decisions',
        'approval_requests',
        'branches',
        'categories',
        'cash_movements',
        'goods_receipt_items',
        'goods_receipts',
        'local_audit_logs',
        'local_metadata',
        'organizations',
        'permissions',
        'product_barcodes',
        'product_images',
        'product_prices',
        'products',
        'purchase_order_items',
        'purchase_orders',
        'registers',
        'refund_payments',
        'role_permissions',
        'roles',
        'sale_return_items',
        'sale_returns',
        'shift_counts',
        'shifts',
        'sync_conflicts',
        'sync_cursors',
        'sync_entity_versions',
        'sync_outbox',
        'supplier_contacts',
        'supplier_products',
        'suppliers',
        'tax_categories',
        'units',
        'user_role_assignments',
      ]),
    );
    expect(database.schemaVersion, AppDatabase.currentSchemaVersion);
  });

  test('health check reports schema and foreign key status', () async {
    final result = await DatabaseHealthCheckService(database).check();

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull?.schemaVersion, AppDatabase.currentSchemaVersion);
    expect(result.valueOrNull?.foreignKeysEnabled, isTrue);
  });

  test('metadata values can be written, observed, and replaced', () async {
    final observed = <String?>[];
    final subscription = database.metadataDao
        .watchValue('active_branch')
        .listen(observed.add);

    await database.metadataDao.writeValue(
      key: 'active_branch',
      value: 'branch-a',
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    await database.metadataDao.writeValue(
      key: 'active_branch',
      value: 'branch-b',
      updatedAt: DateTime.utc(2026, 1, 2),
    );

    expect(await database.metadataDao.readValue('active_branch'), 'branch-b');
    await pumpEventQueue();
    expect(observed, containsAllInOrder(<String?>['branch-a', 'branch-b']));

    await subscription.cancel();
  });

  test('foreign keys reject branch records without an organization', () async {
    final now = DateTime.utc(2026, 1, 1);

    await expectLater(
      database
          .into(database.branches)
          .insert(
            BranchesCompanion.insert(
              id: 'branch-1',
              organizationId: 'missing-org',
              code: 'MAIN',
              name: 'Main',
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('catalog foreign keys reject cross-organization units', () async {
    final now = DateTime.utc(2026, 1, 1);
    for (final value in const [('org-a', 'A'), ('org-b', 'B')]) {
      await database
          .into(database.organizations)
          .insert(
            OrganizationsCompanion.insert(
              id: value.$1,
              code: value.$2,
              name: value.$2,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await database
        .into(database.units)
        .insert(
          UnitsCompanion.insert(
            id: 'unit-b',
            organizationId: 'org-b',
            code: 'PC',
            name: 'Piece',
            abbreviation: 'pc',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await expectLater(
      database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              id: 'product-a',
              organizationId: 'org-a',
              unitId: 'unit-b',
              sku: 'SKU-A',
              normalizedSku: 'SKUA',
              name: 'Product A',
              normalizedName: 'product a',
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('price scope constraint matches branch presence', () async {
    final now = DateTime.utc(2026, 1, 1);
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
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            id: 'product',
            organizationId: 'org',
            unitId: 'unit',
            sku: 'SKU',
            normalizedSku: 'SKU',
            name: 'Product',
            normalizedName: 'product',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await expectLater(
      database
          .into(database.productPrices)
          .insert(
            ProductPricesCompanion.insert(
              id: 'price',
              organizationId: 'org',
              productId: 'product',
              branchScope: 'branch-without-id',
              unitPriceMinor: 100,
              effectiveFrom: now,
              createdByUserId: 'user',
              createdAt: now,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });
}
