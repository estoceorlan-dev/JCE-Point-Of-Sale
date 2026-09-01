import 'package:cloud_functions/cloud_functions.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/models/outbox_command.dart';
import 'package:jce_pos/core/database/models/outbox_state.dart';
import 'package:jce_pos/core/logger/app_logger.dart';
import 'package:jce_pos/core/remote/remote_command_data_source.dart';
import 'package:jce_pos/core/remote/remote_sync_data_source.dart';
import 'package:jce_pos/core/services/backend_sync_service.dart';
import 'package:jce_pos/core/sync/connectivity_monitor.dart';
import 'package:jce_pos/core/sync/remote_change_applier.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const context = BusinessContext(
    organizationId: 'org',
    branchId: 'branch',
    actorUserId: 'user',
  );
  final initialTime = DateTime.utc(2026, 8, 26, 8);
  late AppDatabase database;
  late _MutableClock clock;
  late _Connectivity connectivity;
  late _Commands commands;
  late _Remote remote;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    clock = _MutableClock(initialTime);
    connectivity = _Connectivity(true);
    commands = _Commands();
    remote = _Remote();
    await _seedScope(database, initialTime);
  });

  tearDown(() => database.close());

  OfflineFirstBackendSyncService service({RemoteChangeApplier? applier}) {
    return OfflineFirstBackendSyncService(
      commands: commands,
      remote: remote,
      database: database,
      outboxDao: database.outboxDao,
      cursorDao: database.syncCursorDao,
      conflictDao: database.syncConflictDao,
      versionDao: database.syncEntityVersionDao,
      applier: applier ?? const _NoopApplier(),
      connectivity: connectivity,
      clock: clock,
      logger: const _SilentLogger(),
    );
  }

  test('offline commands synchronize after connectivity returns', () async {
    await _enqueue(database, initialTime, operationId: 'op-1');
    connectivity.connected = false;

    final offline = await service().synchronize(context: context);

    expect(offline.offline, isTrue);
    expect(commands.executed, isEmpty);
    expect(
      (await database.select(database.syncOutboxEntries).getSingle()).status,
      OutboxState.pending.databaseValue,
    );

    connectivity.connected = true;
    final online = await service().synchronize(context: context);

    expect(online.pushed, 1);
    expect(commands.executed, ['op-1']);
    expect(
      (await database.select(database.syncOutboxEntries).getSingle()).status,
      OutboxState.succeeded.databaseValue,
    );
  });

  test('stale processing work resumes after an interrupted run', () async {
    await _enqueue(database, initialTime, operationId: 'op-interrupted');
    await database.outboxDao.claimEligibleBatch(
      now: initialTime,
      organizationId: 'org',
      branchId: 'branch',
      actorUserId: 'user',
    );
    clock.value = initialTime.add(const Duration(minutes: 10));

    final result = await service().synchronize(context: context);

    expect(result.pushed, 1);
    expect(commands.executed, ['op-interrupted']);
  });

  test(
    'same-aggregate commands preserve order while all heads drain',
    () async {
      await _enqueue(
        database,
        initialTime,
        operationId: 'first',
        aggregateId: 'shared',
      );
      await _enqueue(
        database,
        initialTime.add(const Duration(seconds: 1)),
        operationId: 'second',
        aggregateId: 'shared',
      );
      await _enqueue(
        database,
        initialTime,
        operationId: 'unrelated',
        aggregateId: 'other',
      );

      await service().synchronize(context: context);

      expect(
        commands.executed.indexOf('first'),
        lessThan(commands.executed.indexOf('second')),
      );
      expect(commands.executed, containsAll(['first', 'second', 'unrelated']));
    },
  );

  test('a successful operation is never pushed twice', () async {
    await _enqueue(database, initialTime, operationId: 'idempotent');
    final sync = service();

    await sync.synchronize(context: context);
    await sync.synchronize(context: context);

    expect(commands.executed.where((id) => id == 'idempotent'), hasLength(1));
  });

  test('pull application failure does not advance the cursor', () async {
    remote.changes = [_change(sequence: 7)];

    await expectLater(
      service(applier: const _ThrowingApplier()).synchronize(context: context),
      throwsStateError,
    );

    expect(await database.select(database.syncCursors).get(), isEmpty);
  });

  test('version conflicts remain visible and resolvable', () async {
    await _enqueue(
      database,
      initialTime,
      operationId: 'product-conflict',
      commandType: 'product.update',
      aggregateType: 'product',
      aggregateId: 'product-1',
    );
    commands.error = _FunctionsError('aborted');

    await service().synchronize(context: context);

    final outbox = await database
        .select(database.syncOutboxEntries)
        .getSingle();
    final conflict = await database.select(database.syncConflicts).getSingle();
    expect(outbox.status, OutboxState.conflict.databaseValue);
    expect(conflict.entityId, 'product-1');

    await database.outboxDao.retry(conflict.operationId, initialTime);
    await database.syncConflictDao.resolve(
      id: conflict.id,
      resolutionStatus: 'retry_local',
      resolvedAt: initialTime,
    );
    expect(
      (await database.select(database.syncOutboxEntries).getSingle()).status,
      OutboxState.pending.databaseValue,
    );
  });

  test('permanently rejected sales stay visible and actionable', () async {
    await database
        .into(database.registers)
        .insert(
          RegistersCompanion.insert(
            id: 'register',
            organizationId: 'org',
            branchId: 'branch',
            code: 'R1',
            name: 'Register',
            createdAt: initialTime,
            updatedAt: initialTime,
          ),
        );
    await database
        .into(database.sales)
        .insert(
          SalesCompanion.insert(
            id: 'sale-1',
            organizationId: 'org',
            branchId: 'branch',
            registerId: 'register',
            operationId: 'sale-op',
            status: const Value('completed'),
            cashierUserId: 'user',
            completedAt: Value(initialTime),
            createdAt: initialTime,
            updatedAt: initialTime,
          ),
        );
    await _enqueue(
      database,
      initialTime,
      operationId: 'sale-op',
      commandType: 'sale.complete',
      aggregateType: 'sale',
      aggregateId: 'sale-1',
    );
    commands.error = _FunctionsError('invalid-argument');

    await service().synchronize(context: context);

    expect(
      (await database.select(database.sales).getSingle()).status,
      'sync_rejected',
    );
    expect(await database.select(database.syncConflicts).get(), hasLength(1));
    expect(
      (await database.select(database.syncOutboxEntries).getSingle()).status,
      OutboxState.permanentFailure.databaseValue,
    );
  });

  test('two local databases converge on one accepted product', () async {
    final second = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(second.close);
    await _seedScope(second, initialTime);
    for (final db in [database, second]) {
      await db
          .into(db.units)
          .insert(
            UnitsCompanion.insert(
              id: 'unit',
              organizationId: 'org',
              code: 'PC',
              name: 'Piece',
              abbreviation: 'pc',
              createdAt: initialTime,
              updatedAt: initialTime,
            ),
          );
    }
    final change = _change(
      sequence: 1,
      aggregateType: 'product',
      aggregateId: 'product-1',
      payload: {
        'schemaVersion': 1,
        'commandType': 'product.create',
        'actorUserId': 'user',
        'commandPayload': const {},
        'result': {
          'product': {
            'id': 'product-1',
            'organization_id': 'org',
            'unit_id': 'unit',
            'sku': 'SKU-1',
            'name': 'Coffee',
            'is_active': true,
            'version': 0,
            'updated_at': initialTime.toIso8601String(),
            'barcodes': const [],
            'prices': const [],
          },
        },
      },
    );
    for (final db in [database, second]) {
      final source = _Remote()..changes = [change];
      final sync = OfflineFirstBackendSyncService(
        commands: _Commands(),
        remote: source,
        database: db,
        outboxDao: db.outboxDao,
        cursorDao: db.syncCursorDao,
        conflictDao: db.syncConflictDao,
        versionDao: db.syncEntityVersionDao,
        applier: DriftRemoteChangeApplier(db),
        connectivity: _Connectivity(true),
        clock: clock,
        logger: const _SilentLogger(),
      );
      await sync.synchronize(context: context);
    }

    final firstProduct = await database.select(database.products).getSingle();
    final secondProduct = await second.select(second.products).getSingle();
    expect(secondProduct.name, firstProduct.name);
    expect(secondProduct.sku, firstProduct.sku);
  });

  test('customer change feed converges normalized offline lookup', () async {
    final change = _change(
      sequence: 2,
      aggregateType: 'customer',
      aggregateId: 'customer-1',
      payload: {
        'schemaVersion': 1,
        'commandType': 'customer.create',
        'actorUserId': 'user',
        'commandPayload': const {},
        'result': {
          'customer': {
            'id': 'customer-1',
            'customerNumber': 'CUS-00000001',
            'displayName': 'Ana Reyes',
            'normalizedEmail': 'ana@example.com',
            'email': 'ana@example.com',
            'normalizedPhone': '639171234567',
            'phone': '+63 917 123 4567',
            'marketingConsent': false,
            'status': 'active',
            'version': 0,
            'createdAt': initialTime.toIso8601String(),
            'updatedAt': initialTime.toIso8601String(),
          },
          'addresses': const [],
          'notes': const [],
          'loyaltyAccount': null,
          'loyaltyEntries': const [],
        },
      },
    );

    await DriftRemoteChangeApplier(database).apply(change);

    final customer = await database.select(database.customers).getSingle();
    expect(customer.displayName, 'Ana Reyes');
    expect(customer.normalizedEmail, 'ana@example.com');
    expect(customer.normalizedPhone, '639171234567');
  });
}

Future<void> _seedScope(AppDatabase database, DateTime now) async {
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
}

Future<void> _enqueue(
  AppDatabase database,
  DateTime now, {
  required String operationId,
  String commandType = 'category.create',
  String aggregateType = 'category',
  String aggregateId = 'category-1',
}) {
  return database.outboxDao.enqueue(
    OutboxCommand(
      operationId: operationId,
      organizationId: 'org',
      branchId: 'branch',
      actorUserId: 'user',
      commandType: commandType,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      payload: const {'name': 'General'},
      createdAt: now,
    ),
  );
}

RemoteChange _change({
  required int sequence,
  String aggregateType = 'category',
  String aggregateId = 'category-1',
  Object? payload,
}) {
  return RemoteChange(
    sequence: sequence,
    organizationId: 'org',
    branchId: ['product', 'customer'].contains(aggregateType) ? null : 'branch',
    aggregateType: aggregateType,
    aggregateId: aggregateId,
    operationId: 'remote-$sequence',
    changeType: 'upsert',
    version: 0,
    payload: payload ?? const {},
    occurredAt: DateTime.utc(2026, 8, 26, 8),
  );
}

class _Commands implements RemoteCommandDataSource {
  final List<String> executed = [];
  Object? error;

  @override
  Future<RemoteCommandResult> execute(
    SyncOutboxEntry command, {
    Map<String, Object?>? payloadOverride,
  }) async {
    executed.add(command.operationId);
    if (error != null) throw error!;
    return RemoteCommandResult(
      operationId: command.operationId,
      duplicate: false,
      result: const {},
    );
  }
}

class _Remote implements RemoteSyncDataSource {
  List<RemoteChange> changes = [];

  @override
  Future<List<RemoteChange>> pullChanges({
    required String organizationId,
    required String branchId,
    required int afterSequence,
    int limit = 100,
  }) async {
    return changes
        .where((change) => change.sequence > afterSequence)
        .take(limit)
        .toList();
  }

  @override
  Future<ProcessedRemoteOperation?> getProcessedOperation({
    required String organizationId,
    required String branchId,
    required String operationId,
  }) async => null;
}

class _Connectivity implements ConnectivityMonitor {
  _Connectivity(this.connected);
  bool connected;

  @override
  Stream<bool> get changes => const Stream.empty();

  @override
  Future<bool> get isConnected async => connected;
}

class _MutableClock implements AppClock {
  _MutableClock(this.value);
  DateTime value;

  @override
  DateTime nowUtc() => value;
}

class _NoopApplier implements RemoteChangeApplier {
  const _NoopApplier();

  @override
  Future<void> apply(RemoteChange change) async {}
}

class _ThrowingApplier implements RemoteChangeApplier {
  const _ThrowingApplier();

  @override
  Future<void> apply(RemoteChange change) => throw StateError('apply failed');
}

class _FunctionsError extends FirebaseFunctionsException {
  _FunctionsError(String code) : super(code: code, message: 'Rejected');
}

class _SilentLogger implements AppLogger {
  const _SilentLogger();
  @override
  void debug(String message, {String? scope}) {}
  @override
  void error(
    String message, {
    String? scope,
    Object? error,
    StackTrace? stackTrace,
  }) {}
  @override
  void info(String message, {String? scope}) {}
  @override
  void warning(
    String message, {
    String? scope,
    Object? error,
    StackTrace? stackTrace,
  }) {}
}
