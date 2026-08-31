import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';

import 'migrations/app_database/generated/schema.dart';

void main() {
  test('current schema matches the generated current snapshot', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());

    await database.validateDatabaseSchema();

    await database.close();
  });

  test(
    'released version 1 schema opens and validates without data loss',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(1);
      schema.rawDatabase.execute(
        'INSERT INTO local_metadata (`key`, `value`, `updated_at`) '
        "VALUES ('preserved', 'yes', '1970-01-01T00:00:00.000Z')",
      );

      final database = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(
        database,
        AppDatabase.currentSchemaVersion,
      );

      expect(await database.metadataDao.readValue('preserved'), 'yes');

      await database.close();
      schema.close();
    },
  );

  test(
    'released version 2 catalog migrates to ownership constraints',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(2);
      const timestamp = '2026-06-28T00:00:00.000Z';
      schema.rawDatabase.execute('''INSERT INTO organizations
(id, code, name, timezone, is_active, created_at, updated_at)
VALUES ('org', 'JCE', 'JCE', 'Asia/Manila', 1,
'$timestamp', '$timestamp')''');
      schema.rawDatabase.execute('''INSERT INTO branches
(id, organization_id, code, name, timezone, is_active,
created_at, updated_at) VALUES
('branch', 'org', 'MAIN', 'Main', 'Asia/Manila', 1,
'$timestamp', '$timestamp')''');
      schema.rawDatabase.execute('''INSERT INTO units
(id, organization_id, code, name, abbreviation, allows_fractional,
is_active, created_at, updated_at) VALUES
('unit', 'org', 'PC', 'Piece', 'pc', 0, 1,
'$timestamp', '$timestamp')''');
      schema.rawDatabase.execute('''INSERT INTO products
(id, organization_id, unit_id, sku, normalized_sku, name,
normalized_name, is_active, created_at, updated_at) VALUES
('product', 'org', 'unit', 'SKU-1', 'SKU1', 'Product',
'product', 1, '$timestamp', '$timestamp')''');
      schema.rawDatabase.execute('''INSERT INTO product_prices
(id, organization_id, product_id, branch_scope, unit_price_minor,
effective_from, created_by_user_id, created_at) VALUES
('price', 'org', 'product', '*', 10000, '$timestamp',
'user', '$timestamp')''');

      final database = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(
        database,
        AppDatabase.currentSchemaVersion,
      );

      expect(await database.select(database.products).get(), hasLength(1));
      expect(await database.select(database.productPrices).get(), hasLength(1));

      await database.close();
      schema.close();
    },
  );

  test('released version 3 catalog migrates to inventory schema', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(3);
    const timestamp = '2026-08-24T00:00:00.000Z';
    schema.rawDatabase.execute('''INSERT INTO organizations
(id, code, name, timezone, is_active, created_at, updated_at)
VALUES ('org', 'JCE', 'JCE', 'Asia/Manila', 1,
'$timestamp', '$timestamp')''');
    schema.rawDatabase.execute('''INSERT INTO branches
(id, organization_id, code, name, timezone, is_active,
created_at, updated_at) VALUES
('branch', 'org', 'MAIN', 'Main', 'Asia/Manila', 1,
'$timestamp', '$timestamp')''');
    schema.rawDatabase.execute('''INSERT INTO units
(id, organization_id, code, name, abbreviation, allows_fractional,
is_active, created_at, updated_at) VALUES
('unit', 'org', 'PC', 'Piece', 'pc', 0, 1,
'$timestamp', '$timestamp')''');
    schema.rawDatabase.execute('''INSERT INTO products
(id, organization_id, unit_id, sku, normalized_sku, name,
normalized_name, is_active, created_at, updated_at) VALUES
('product', 'org', 'unit', 'SKU-1', 'SKU1', 'Product',
'product', 1, '$timestamp', '$timestamp')''');

    final database = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(
      database,
      AppDatabase.currentSchemaVersion,
    );

    expect(await database.select(database.products).get(), hasLength(1));
    final branch = await database.select(database.branches).getSingle();
    expect(branch.allowNegativeStock, isFalse);
    expect(branch.adjustmentApprovalThresholdMilli, isNull);
    expect(await database.select(database.stockLocations).get(), isEmpty);
    expect(
      await database.select(database.inventoryLedgerEntries).get(),
      isEmpty,
    );
    expect(await database.select(database.stockCounts).get(), isEmpty);

    await database.close();
    schema.close();
  });

  test('released version 4 inventory migrates to shift schema', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(4);
    const timestamp = '2026-08-24T00:00:00.000Z';
    schema.rawDatabase.execute('''INSERT INTO organizations
(id, code, name, timezone, is_active, created_at, updated_at)
VALUES ('org', 'JCE', 'JCE', 'Asia/Manila', 1,
'$timestamp', '$timestamp')''');
    schema.rawDatabase.execute('''INSERT INTO branches
(id, organization_id, code, name, timezone, is_active,
allow_negative_stock, created_at, updated_at) VALUES
('branch', 'org', 'MAIN', 'Main', 'Asia/Manila', 1, 0,
'$timestamp', '$timestamp')''');
    schema.rawDatabase.execute('''INSERT INTO stock_locations
(id, organization_id, branch_id, code, name, location_type,
is_default, is_active, created_at, updated_at) VALUES
('location', 'org', 'branch', 'MAIN', 'Main', 'warehouse', 1, 1,
'$timestamp', '$timestamp')''');

    final database = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(
      database,
      AppDatabase.currentSchemaVersion,
    );

    final branch = await database.select(database.branches).getSingle();
    expect(branch.allowMultipleOpenShiftsPerUser, isFalse);
    expect(branch.allowSalesWithoutOpenShift, isFalse);
    expect(branch.cashDiscrepancyApprovalThresholdMinor, isNull);
    expect(await database.select(database.stockLocations).get(), hasLength(1));
    expect(await database.select(database.registers).get(), isEmpty);
    expect(await database.select(database.shifts).get(), isEmpty);
    expect(await database.select(database.cashMovements).get(), isEmpty);
    expect(await database.select(database.shiftCounts).get(), isEmpty);

    await database.close();
    schema.close();
  });

  test('released version 5 shifts migrate to the sales schema', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(5);
    const timestamp = '2026-08-25T00:00:00.000Z';
    schema.rawDatabase.execute('''INSERT INTO organizations
(id, code, name, timezone, is_active, created_at, updated_at)
VALUES ('org', 'JCE', 'JCE', 'Asia/Manila', 1,
'$timestamp', '$timestamp')''');
    schema.rawDatabase.execute('''INSERT INTO branches
(id, organization_id, code, name, timezone, is_active,
allow_negative_stock, allow_multiple_open_shifts_per_user,
allow_sales_without_open_shift, created_at, updated_at) VALUES
('branch', 'org', 'MAIN', 'Main', 'Asia/Manila', 1, 0, 0, 0,
'$timestamp', '$timestamp')''');

    final database = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(
      database,
      AppDatabase.currentSchemaVersion,
    );

    final branch = await database.select(database.branches).getSingle();
    expect(branch.discountApprovalThresholdBasisPoints, isNull);
    expect(await database.select(database.sales).get(), isEmpty);
    expect(await database.select(database.saleItems).get(), isEmpty);
    expect(await database.select(database.payments).get(), isEmpty);
    expect(await database.select(database.saleDiscounts).get(), isEmpty);
    expect(await database.select(database.receiptSequences).get(), isEmpty);

    await database.close();
    schema.close();
  });

  test(
    'released version 6 outbox gains owner scope and sync versions',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(6);
      const timestamp = '2026-08-26T00:00:00.000Z';
      schema.rawDatabase.execute('''INSERT INTO sync_outbox
(operation_id, organization_id, branch_id, command_type, aggregate_type,
aggregate_id, payload_json, status, created_at, updated_at) VALUES
('op', 'org', 'branch', 'category.create', 'category', 'category-1',
'{}', 'pending', '$timestamp', '$timestamp')''');
      schema.rawDatabase.execute('''INSERT INTO local_audit_logs
(id, operation_id, organization_id, actor_user_id, branch_id, action_type,
entity_name, entity_id, metadata_json, created_at) VALUES
('audit', 'op', 'org', 'user', 'branch', 'create', 'category',
'category-1', '{}', '$timestamp')''');

      final database = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(
        database,
        AppDatabase.currentSchemaVersion,
      );

      final outbox = await database
          .select(database.syncOutboxEntries)
          .getSingle();
      expect(outbox.actorUserId, 'user');
      expect(await database.select(database.syncEntityVersions).get(), isEmpty);

      await database.close();
      schema.close();
    },
  );

  test('released version 7 sync schema migrates to corrections', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(7);
    final database = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(
      database,
      AppDatabase.currentSchemaVersion,
    );
    final now = DateTime.utc(2026, 8, 29);
    await database
        .into(database.organizations)
        .insert(
          OrganizationsCompanion.insert(
            id: 'org-v8',
            code: 'V8',
            name: 'Version 8',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.branches)
        .insert(
          BranchesCompanion.insert(
            id: 'branch-v8',
            organizationId: 'org-v8',
            code: 'MAIN',
            name: 'Main',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final branch = await database.select(database.branches).getSingle();
    expect(branch.returnApprovalThresholdMinor, isNull);
    expect(branch.voidWindowMinutes, 15);
    expect(await database.select(database.saleReturns).get(), isEmpty);
    expect(await database.select(database.approvalRequests).get(), isEmpty);

    await database.close();
    schema.close();
  });

  test('released version 8 corrections migrate to stock transfers', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(8);
    final database = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(
      database,
      AppDatabase.currentSchemaVersion,
    );
    final now = DateTime.utc(2026, 8, 31);
    await database
        .into(database.organizations)
        .insert(
          OrganizationsCompanion.insert(
            id: 'org-v9',
            code: 'V9',
            name: 'Version 9',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.branches)
        .insert(
          BranchesCompanion.insert(
            id: 'branch-v9',
            organizationId: 'org-v9',
            code: 'MAIN',
            name: 'Main',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final branch = await database.select(database.branches).getSingle();
    expect(branch.transferApprovalThresholdMilli, isNull);
    expect(await database.select(database.stockTransfers).get(), isEmpty);
    expect(await database.select(database.stockTransferItems).get(), isEmpty);
    expect(await database.select(database.transferEvents).get(), isEmpty);

    await database.close();
    schema.close();
  });
}
