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
}
