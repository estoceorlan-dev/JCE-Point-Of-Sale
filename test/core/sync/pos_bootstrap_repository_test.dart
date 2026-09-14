import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/models/sync_cursor_key.dart';
import 'package:jce_pos/core/remote/pos_bootstrap_remote_data_source.dart';
import 'package:jce_pos/core/sync/drift_pos_bootstrap_repository.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  const context = BusinessContext(
    organizationId: 'organization',
    branchId: 'branch',
    actorUserId: 'cashier',
  );
  final stamp = DateTime.utc(2026, 9, 10, 8);
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database
        .into(database.organizations)
        .insert(
          OrganizationsCompanion.insert(
            id: 'organization',
            code: 'OLD',
            name: 'Old organization',
            createdAt: stamp,
            updatedAt: stamp,
          ),
        );
    await database
        .into(database.branches)
        .insert(
          BranchesCompanion.insert(
            id: 'branch',
            organizationId: 'organization',
            code: 'OLD',
            name: 'Old branch',
            createdAt: stamp,
            updatedAt: stamp,
          ),
        );
  });

  tearDown(() => database.close());

  test(
    'an interrupted bootstrap leaves the published cache untouched',
    () async {
      final remote = _BootstrapRemote(stamp)..failAt = 'categories';
      final repository = DriftPosBootstrapRepository(
        database: database,
        remote: remote,
      );

      final failed = await repository.provision(context, force: true);

      expect(failed.isFailure, isTrue);
      expect(
        (await database.select(database.organizations).getSingle()).name,
        'Old organization',
      );
      expect(
        (await database.select(database.branches).getSingle()).name,
        'Old branch',
      );
      expect(
        await database.metadataDao.readValue(
          'pos_bootstrap_ready:organization:branch',
        ),
        isNull,
      );
      expect(
        await database.select(database.syncSnapshotStagingRecords).get(),
        isNotEmpty,
      );
    },
  );

  test('a complete bootstrap publishes one coherent usable cache', () async {
    final repository = DriftPosBootstrapRepository(
      database: database,
      remote: _BootstrapRemote(stamp),
    );

    final result = await repository.provision(context, force: true);

    expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
    expect(
      (await database.select(database.organizations).getSingle()).name,
      'JCE',
    );
    expect((await database.select(database.branches).getSingle()).name, 'Main');
    expect((await database.select(database.products).getSingle()).name, 'Rice');
    expect(
      (await database.select(database.stockLocations).getSingle()).isDefault,
      isTrue,
    );
    expect(await repository.hasUsableCache(context), isTrue);
    expect(
      await database.select(database.syncSnapshotStagingRecords).get(),
      isEmpty,
    );
    final cursor = await database.syncCursorDao.read(
      const SyncCursorKey(
        scope: 'remote-change-feed',
        organizationId: 'organization',
        branchId: 'branch',
        projection: 'pos_sync_v2',
        actorUserId: 'cashier',
      ),
    );
    expect(cursor?.lastChangeSequence, 42);
  });
}

class _BootstrapRemote implements PosBootstrapRemoteDataSource {
  _BootstrapRemote(this.stamp);

  final DateTime stamp;
  String? failAt;

  @override
  Future<PosBootstrapPage> fetchPage({
    required String organizationId,
    required String branchId,
    required String collection,
    String? snapshotToken,
    String? cursor,
    int pageSize = 250,
  }) async {
    if (collection == failAt) throw StateError('interrupted download');
    final rows = _rows(collection);
    final pageCursor = cursor ?? '';
    final checksum = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'collection': collection,
              'cursor': pageCursor,
              'rows': rows,
            }),
          ),
        )
        .toString();
    return PosBootstrapPage(
      snapshotToken: snapshotToken ?? 'snapshot',
      collection: collection,
      cursor: pageCursor,
      nextCursor: null,
      watermark: 42,
      checksum: checksum,
      rows: rows,
      complete: true,
    );
  }

  List<Map<String, Object?>> _rows(String collection) {
    final createdAt = stamp.toIso8601String();
    return switch (collection) {
      'organization' => [
        {
          'id': 'organization',
          'code': 'JCE',
          'name': 'JCE',
          'timezone': 'Asia/Manila',
          'is_active': true,
          'created_at': createdAt,
          'updated_at': createdAt,
        },
      ],
      'branch' => [
        {
          'id': 'branch',
          'code': 'MAIN',
          'name': 'Main',
          'timezone': 'Asia/Manila',
          'is_active': true,
          'created_at': createdAt,
          'updated_at': createdAt,
        },
      ],
      'units' => [
        {
          'id': 'unit',
          'code': 'PC',
          'name': 'Piece',
          'abbreviation': 'pc',
          'allows_fractional': false,
          'is_active': true,
          'created_at': createdAt,
          'updated_at': createdAt,
        },
      ],
      'products' => [
        {
          'id': 'product',
          'unit_id': 'unit',
          'sku': 'RICE-1',
          'normalized_sku': 'RICE-1',
          'name': 'Rice',
          'normalized_name': 'rice',
          'is_active': true,
          'created_at': createdAt,
          'updated_at': createdAt,
        },
      ],
      'stockLocations' => [
        {
          'id': 'location',
          'code': 'FLOOR',
          'name': 'Sales Floor',
          'location_type': 'sales_floor',
          'is_default': true,
          'is_active': true,
          'version': 0,
          'created_at': createdAt,
          'updated_at': createdAt,
        },
      ],
      _ => const [],
    };
  }
}
