import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/remote/remote_sync_data_source.dart';
import 'package:jce_pos/core/sync/remote_change_envelope.dart';
import 'package:jce_pos/core/sync/stock_location_change_applier.dart';

void main() {
  late AppDatabase database;
  const timestamp = '2026-09-07T00:00:00.000Z';

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.parse(timestamp);
    await database
        .into(database.organizations)
        .insert(
          OrganizationsCompanion.insert(
            id: 'organization',
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
            organizationId: 'organization',
            code: 'MAIN',
            name: 'Main branch',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.stockLocations)
        .insert(
          StockLocationsCompanion.insert(
            id: 'location',
            organizationId: 'organization',
            branchId: 'branch',
            code: 'WAREHOUSE',
            name: 'Warehouse',
            isDefault: const Value(true),
            version: const Value(2),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(() => database.close());

  test(
    'archive change applies its immutable remote projection and version',
    () async {
      await StockLocationChangeApplier(database).apply(
        _envelope(
          result: {
            'stockLocation': _row(
              isActive: false,
              isDefault: false,
              version: 3,
            ),
          },
        ),
      );

      final location = await database
          .select(database.stockLocations)
          .getSingle();
      expect(location.isActive, isFalse);
      expect(location.isDefault, isFalse);
      expect(location.version, 3);
      expect(location.deletedAt, DateTime.parse(timestamp));
      expect(
        await database.syncEntityVersionDao.readVersion(
          organizationId: 'organization',
          entityType: 'stock_location',
          entityId: 'location',
        ),
        3,
      );
    },
  );

  test(
    'an older remote location projection cannot overwrite a newer local row',
    () async {
      await (database.update(
        database.stockLocations,
      )..where((row) => row.id.equals('location'))).write(
        StockLocationsCompanion(
          name: const Value('Newer local name'),
          version: const Value(4),
        ),
      );

      await StockLocationChangeApplier(
        database,
      ).apply(_envelope(result: {'stockLocation': _row(version: 3)}));

      final location = await database
          .select(database.stockLocations)
          .getSingle();
      expect(location.name, 'Newer local name');
      expect(location.version, 4);
    },
  );
}

RemoteChangeEnvelope _envelope({required Map<String, Object?> result}) {
  final occurredAt = DateTime.parse('2026-09-07T00:00:00.000Z');
  return RemoteChangeEnvelope(
    change: RemoteChange(
      sequence: 1,
      organizationId: 'organization',
      branchId: 'branch',
      aggregateType: 'stock_location',
      aggregateId: 'location',
      operationId: 'operation',
      changeType: 'tombstone',
      version: 3,
      payload: const {},
      occurredAt: occurredAt,
    ),
    commandType: 'stock_location.archive',
    actorUserId: 'user',
    commandPayload: const {},
    result: result,
  );
}

Map<String, Object?> _row({
  bool isActive = true,
  bool isDefault = true,
  int version = 3,
}) => {
  'id': 'location',
  'organization_id': 'organization',
  'branch_id': 'branch',
  'code': 'WAREHOUSE',
  'name': 'Warehouse',
  'location_type': 'warehouse',
  'is_default': isDefault,
  'is_active': isActive,
  'version': version,
  'created_at': '2026-09-07T00:00:00.000Z',
  'updated_at': '2026-09-07T00:00:00.000Z',
  'deleted_at': isActive ? null : '2026-09-07T00:00:00.000Z',
};
