import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'generated/schema.dart';

void main() {
  test(
    'schema 15 preserves locations and seeds the last known remote version',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(15);
      const stamp = '2026-09-07T00:00:00.000Z';
      schema.rawDatabase.execute(
        "INSERT INTO organizations (id, code, name, created_at, updated_at) VALUES ('o', 'ORG', 'Org', '$stamp', '$stamp')",
      );
      schema.rawDatabase.execute(
        "INSERT INTO branches (id, organization_id, code, name, created_at, updated_at) VALUES ('b', 'o', 'MAIN', 'Main', '$stamp', '$stamp')",
      );
      schema.rawDatabase.execute(
        "INSERT INTO stock_locations (id, organization_id, branch_id, code, name, created_at, updated_at) VALUES ('l', 'o', 'b', 'STORE', 'Store', '$stamp', '$stamp')",
      );
      schema.rawDatabase.execute(
        "INSERT INTO sync_entity_versions (entity_key, organization_id, branch_id, entity_type, entity_id, remote_version, updated_at) VALUES ('o::stock_location::l', 'o', 'b', 'stock_location', 'l', 4, '$stamp')",
      );
      final database = AppDatabase.forTesting(schema.newConnection());
      try {
        await verifier.migrateAndValidate(
          database,
          AppDatabase.currentSchemaVersion,
        );
        final location = await database
            .select(database.stockLocations)
            .getSingle();
        expect(location.id, 'l');
        expect(location.name, 'Store');
        expect(location.isActive, isTrue);
        expect(location.version, 4);
      } finally {
        await database.close();
        schema.close();
      }
    },
  );

  test('schema 16 migrates carts to empty schema 17 recovery fields', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(16);
    const stamp = '2026-09-08T00:00:00.000Z';
    schema.rawDatabase.execute(
      "INSERT INTO organizations (id, code, name, created_at, updated_at) VALUES ('o', 'ORG', 'Org', '$stamp', '$stamp')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO branches (id, organization_id, code, name, created_at, updated_at) VALUES ('b', 'o', 'MAIN', 'Main', '$stamp', '$stamp')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO pos_carts (id, organization_id, branch_id, device_id, status, active_scope, created_at, updated_at) VALUES ('cart', 'o', 'b', 'device', 'active', 'o|b|device', '$stamp', '$stamp')",
    );
    final database = AppDatabase.forTesting(schema.newConnection());
    try {
      await verifier.migrateAndValidate(
        database,
        AppDatabase.currentSchemaVersion,
      );
      final cart = await database.select(database.posCarts).getSingle();
      expect(cart.id, 'cart');
      expect(cart.checkoutOperationId, isNull);
      expect(cart.checkoutTendersJson, isNull);
      expect(cart.externalPaymentApproved, isFalse);
      expect(cart.checkoutAttemptedAt, isNull);
    } finally {
      await database.close();
      schema.close();
    }
  });

  test('schema 17 migrates to catalog lookup indexes without data loss', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(17);
    const stamp = '2026-09-09T00:00:00.000Z';
    schema.rawDatabase.execute(
      "INSERT INTO organizations (id, code, name, created_at, updated_at) VALUES ('o', 'ORG', 'Org', '$stamp', '$stamp')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO branches (id, organization_id, code, name, created_at, updated_at) VALUES ('b', 'o', 'MAIN', 'Main', '$stamp', '$stamp')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO units (id, organization_id, code, name, abbreviation, created_at, updated_at) VALUES ('u', 'o', 'PC', 'Piece', 'pc', '$stamp', '$stamp')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO products (id, organization_id, unit_id, sku, normalized_sku, name, normalized_name, created_at, updated_at) VALUES ('p', 'o', 'u', 'SKU', 'SKU', 'Product', 'product', '$stamp', '$stamp')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO product_barcodes (id, organization_id, product_id, barcode, normalized_barcode, created_at, updated_at) VALUES ('pb', 'o', 'p', '123', '123', '$stamp', '$stamp')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO product_prices (id, organization_id, product_id, branch_scope, unit_price_minor, effective_from, created_by_user_id, created_at) VALUES ('pp', 'o', 'p', '*', 100, '$stamp', 'user', '$stamp')",
    );
    final database = AppDatabase.forTesting(schema.newConnection());
    try {
      await verifier.migrateAndValidate(
        database,
        AppDatabase.currentSchemaVersion,
      );
      expect(await database.select(database.products).get(), hasLength(1));
      expect(
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name IN ('product_barcodes_product_lookup_idx', "
              "'product_prices_lookup_idx') ORDER BY name",
            )
            .map((row) => row.read<String>('name'))
            .get(),
        ['product_barcodes_product_lookup_idx', 'product_prices_lookup_idx'],
      );
    } finally {
      await database.close();
      schema.close();
    }
  });
}
