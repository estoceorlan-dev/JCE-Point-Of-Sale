import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/models/outbox_command.dart';
import 'package:jce_pos/core/remote/remote_sync_data_source.dart';
import 'package:jce_pos/core/services/administration_snapshot_service.dart';
import 'package:jce_pos/core/sync/remote_change_applier.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  late AppDatabase database;
  late AdministrationSnapshotService service;
  late Map<String, Object?> snapshot;
  var calls = 0;
  var offline = false;
  final now = DateTime.utc(2026, 9, 6);
  const context = BusinessContext(
    organizationId: 'org',
    branchId: 'main',
    actorUserId: 'admin',
  );
  Map<String, Object?> branch({int version = 2, String organization = 'org'}) =>
      {
        'id': 'main',
        'organizationId': organization,
        'code': 'MAIN',
        'name': 'Server branch',
        'timezone': 'Asia/Manila',
        'isActive': true,
        'version': version,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
  Future<SyncConflict> conflict() async {
    await service.hydrateIfNeeded(context);
    await (database.update(
      database.branches,
    )..where((row) => row.id.equals('main'))).write(
      const BranchesCompanion(name: Value('Local conflict'), version: Value(9)),
    );
    await database.outboxDao.enqueue(
      OutboxCommand(
        operationId: 'op',
        commandType: 'branch.update',
        aggregateType: 'branch',
        aggregateId: 'main',
        organizationId: 'org',
        branchId: 'main',
        actorUserId: 'admin',
        payload: const {},
        createdAt: now,
      ),
    );
    await database.outboxDao.markConflict(
      operationId: 'op',
      error: 'conflict',
      now: now,
    );
    await database.syncConflictDao.add(
      SyncConflictsCompanion.insert(
        id: 'conflict',
        operationId: 'op',
        organizationId: const Value('org'),
        branchId: const Value('main'),
        actorUserId: const Value('admin'),
        entityType: 'branch',
        entityId: 'main',
        localPayloadJson: '{}',
        remotePayloadJson: '{}',
        reason: 'conflict',
        resolutionStatus: 'unresolved',
        createdAt: now,
      ),
    );
    return (await database.syncConflictDao.unresolvedForOperation('op'))!;
  }

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    calls = 0;
    offline = false;
    snapshot = {
      'schemaVersion': 1,
      'organizationId': 'org',
      'branches': [branch()],
      'generatedAt': now.toIso8601String(),
    };
    service = AdministrationSnapshotService(
      database: database,
      demoMode: false,
      loadSnapshot: (_) async {
        calls++;
        if (offline) throw StateError('offline');
        return snapshot;
      },
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
  });
  tearDown(() => database.close());

  test('snapshot completion is scoped to actor and permission set', () async {
    await service.hydrateIfNeeded(context, scopeKey: 'branches.manage');
    await service.hydrateIfNeeded(context, scopeKey: 'branches.manage');
    expect(calls, 1);
    await service.hydrateIfNeeded(
      context,
      scopeKey: 'branches.manage,roles.manage',
    );
    await service.hydrateIfNeeded(
      const BusinessContext(
        organizationId: 'org',
        branchId: 'main',
        actorUserId: 'other',
      ),
      scopeKey: 'branches.manage',
    );
    expect(calls, 3);
  });

  test(
    'older feed replay and stale snapshots cannot replace hydrated branch',
    () async {
      await service.hydrateIfNeeded(context);
      await DriftRemoteChangeApplier(database).apply(
        RemoteChange(
          sequence: 1,
          organizationId: 'org',
          branchId: null,
          aggregateType: 'branch',
          aggregateId: 'main',
          operationId: 'older',
          changeType: 'updated',
          version: 1,
          payload: const {},
          occurredAt: now,
        ),
      );
      snapshot['branches'] = [branch(version: 1)..['name'] = 'Old name'];
      await service.hydrateIfNeeded(context, force: true);
      final row = await database.select(database.branches).getSingle();
      expect(row.name, 'Server branch');
      expect(row.version, 2);
    },
  );

  test('snapshot preserves unresolved local edits', () async {
    await conflict();
    await service.hydrateIfNeeded(context, force: true);
    expect(
      (await database.select(database.branches).getSingle()).name,
      'Local conflict',
    );
    expect(
      await database.syncConflictDao.unresolvedForOperation('op'),
      isNotNull,
    );
  });

  test(
    'incremental feed cannot overwrite unresolved administration edits',
    () async {
      await conflict();
      await DriftRemoteChangeApplier(database).apply(
        RemoteChange(
          sequence: 10,
          organizationId: 'org',
          branchId: null,
          aggregateType: 'branch',
          aggregateId: 'main',
          operationId: 'other-device',
          changeType: 'updated',
          version: 3,
          payload: const {},
          occurredAt: now,
        ),
      );
      expect(
        (await database.select(database.branches).getSingle()).name,
        'Local conflict',
      );
    },
  );

  test(
    'accept remote restores projection even after feed cursor has advanced',
    () async {
      final value = await conflict();
      await service.acceptRemote(context, value);
      expect(
        (await database.select(database.branches).getSingle()).name,
        'Server branch',
      );
      expect((await database.select(database.branches).getSingle()).version, 2);
      expect(
        (await database.select(database.syncOutboxEntries).getSingle()).status,
        'discarded',
      );
      expect(
        await database.syncConflictDao.unresolvedForOperation('op'),
        isNull,
      );
    },
  );

  test(
    'offline acceptance leaves local conflict and outbox recoverable',
    () async {
      final value = await conflict();
      offline = true;
      await expectLater(service.acceptRemote(context, value), throwsStateError);
      expect(
        (await database.select(database.branches).getSingle()).name,
        'Local conflict',
      );
      expect(
        (await database.select(database.syncOutboxEntries).getSingle()).status,
        'conflict',
      );
      expect(
        await database.syncConflictDao.unresolvedForOperation('op'),
        isNotNull,
      );
    },
  );

  test(
    'foreign snapshot fails atomically without completing hydration',
    () async {
      snapshot['branches'] = [branch(organization: 'foreign')];
      await expectLater(
        service.hydrateIfNeeded(context),
        throwsFormatException,
      );
      expect(await database.select(database.branches).get(), isEmpty);
      snapshot['branches'] = [branch()];
      await service.hydrateIfNeeded(context);
      expect(calls, 2);
    },
  );

  test('acceptance blocks dependent pending edits and another actor', () async {
    final value = await conflict();
    await expectLater(
      service.acceptRemote(
        const BusinessContext(
          organizationId: 'org',
          branchId: 'main',
          actorUserId: 'other',
        ),
        value,
      ),
      throwsStateError,
    );
    await database.outboxDao.enqueue(
      OutboxCommand(
        operationId: 'next',
        commandType: 'branch.update',
        aggregateType: 'branch',
        aggregateId: 'main',
        organizationId: 'org',
        payload: const {},
        createdAt: now,
      ),
    );
    await expectLater(service.acceptRemote(context, value), throwsStateError);
    expect(
      await database.syncConflictDao.unresolvedForOperation('op'),
      isNotNull,
    );
  });
}
