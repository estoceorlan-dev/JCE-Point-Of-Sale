import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/business_context.dart';
import '../config/app_config.dart';
import '../database/app_database.dart';
import '../database/daos/outbox_dao.dart';
import '../database/daos/sync_conflict_dao.dart';
import '../database/daos/sync_cursor_dao.dart';
import '../database/daos/sync_entity_version_dao.dart';
import '../database/database_provider.dart';
import '../database/models/outbox_state.dart';
import '../database/models/sync_cursor_key.dart';
import '../database/outbox_retry_policy.dart';
import '../logger/app_logger.dart';
import '../remote/firebase_functions_provider.dart';
import '../remote/remote_command_data_source.dart';
import '../remote/remote_sync_data_source.dart';
import '../sync/connectivity_monitor.dart';
import '../sync/remote_change_applier.dart';
import '../utils/app_clock.dart';

final remoteCommandDataSourceProvider = Provider<RemoteCommandDataSource>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  return CloudFunctionsRemoteCommandDataSource(
    functions: ref.watch(firebaseFunctionsProvider),
    functionName: config.remoteCommandFunctionName,
    deviceRegistrationFunctionName: config.deviceRegistrationFunctionName,
  );
});

final remoteSyncDataSourceProvider = Provider<RemoteSyncDataSource>((ref) {
  return SqlConnectRemoteSyncDataSource();
});

final remoteChangeApplierProvider = Provider<RemoteChangeApplier>((ref) {
  return DriftRemoteChangeApplier(ref.watch(appDatabaseProvider));
});

final backendSyncServiceProvider = Provider<BackendSyncService>((ref) {
  return OfflineFirstBackendSyncService(
    commands: ref.watch(remoteCommandDataSourceProvider),
    remote: ref.watch(remoteSyncDataSourceProvider),
    database: ref.watch(appDatabaseProvider),
    outboxDao: ref.watch(outboxDaoProvider),
    cursorDao: ref.watch(syncCursorDaoProvider),
    conflictDao: ref.watch(syncConflictDaoProvider),
    versionDao: ref.watch(syncEntityVersionDaoProvider),
    applier: ref.watch(remoteChangeApplierProvider),
    connectivity: ref.watch(connectivityMonitorProvider),
    clock: ref.watch(appClockProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

enum SyncTrigger { manual, signIn, reconnect, foreground, periodic, background }

class SyncRunResult {
  const SyncRunResult({
    required this.trigger,
    required this.startedAt,
    required this.finishedAt,
    required this.pushed,
    required this.pulled,
    required this.conflicts,
    required this.offline,
  });

  final SyncTrigger trigger;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int pushed;
  final int pulled;
  final int conflicts;
  final bool offline;
}

abstract interface class BackendSyncService {
  Future<SyncRunResult> synchronize({
    required BusinessContext context,
    SyncTrigger trigger = SyncTrigger.manual,
  });
}

class OfflineFirstBackendSyncService implements BackendSyncService {
  OfflineFirstBackendSyncService({
    required RemoteCommandDataSource commands,
    required RemoteSyncDataSource remote,
    required AppDatabase database,
    required OutboxDao outboxDao,
    required SyncCursorDao cursorDao,
    required SyncConflictDao conflictDao,
    required SyncEntityVersionDao versionDao,
    required RemoteChangeApplier applier,
    required ConnectivityMonitor connectivity,
    required AppClock clock,
    required AppLogger logger,
  }) : _commands = commands,
       _remote = remote,
       _database = database,
       _outboxDao = outboxDao,
       _cursorDao = cursorDao,
       _conflictDao = conflictDao,
       _versionDao = versionDao,
       _applier = applier,
       _connectivity = connectivity,
       _clock = clock,
       _logger = logger;

  static const _cursorScope = 'remote-change-feed';
  static const _staleProcessingAge = Duration(minutes: 5);
  static const _pushBatchSize = 25;
  static const _maximumPushBatches = 20;
  static const _pullBatchSize = 100;
  static const _maximumPullBatches = 20;

  final RemoteCommandDataSource _commands;
  final RemoteSyncDataSource _remote;
  final AppDatabase _database;
  final OutboxDao _outboxDao;
  final SyncCursorDao _cursorDao;
  final SyncConflictDao _conflictDao;
  final SyncEntityVersionDao _versionDao;
  final RemoteChangeApplier _applier;
  final ConnectivityMonitor _connectivity;
  final AppClock _clock;
  final AppLogger _logger;

  Future<SyncRunResult>? _activeRun;

  @override
  Future<SyncRunResult> synchronize({
    required BusinessContext context,
    SyncTrigger trigger = SyncTrigger.manual,
  }) {
    final active = _activeRun;
    if (active != null) return active;
    final run = _synchronize(context, trigger);
    _activeRun = run;
    return run.whenComplete(() => _activeRun = null);
  }

  Future<SyncRunResult> _synchronize(
    BusinessContext context,
    SyncTrigger trigger,
  ) async {
    final startedAt = _clock.nowUtc();
    if (!await _connectivity.isConnected) {
      return SyncRunResult(
        trigger: trigger,
        startedAt: startedAt,
        finishedAt: _clock.nowUtc(),
        pushed: 0,
        pulled: 0,
        conflicts: 0,
        offline: true,
      );
    }

    var pushed = 0;
    var conflicts = 0;
    for (
      var batchNumber = 0;
      batchNumber < _maximumPushBatches;
      batchNumber++
    ) {
      final now = _clock.nowUtc();
      await _outboxDao.recoverStaleProcessing(
        staleBefore: now.subtract(_staleProcessingAge),
        now: now,
      );
      final batch = await _outboxDao.claimEligibleBatch(
        now: now,
        organizationId: context.organizationId,
        branchId: context.branchId,
        actorUserId: context.actorUserId,
        limit: _pushBatchSize,
      );
      if (batch.isEmpty) break;
      final outcomes = await Future.wait([
        for (final command in batch) _pushOne(context, command),
      ]);
      pushed += outcomes
          .where((outcome) => outcome == _PushOutcome.succeeded)
          .length;
      conflicts += outcomes
          .where((outcome) => outcome == _PushOutcome.conflict)
          .length;
    }

    final pulled = await _pullAndApply(context);
    return SyncRunResult(
      trigger: trigger,
      startedAt: startedAt,
      finishedAt: _clock.nowUtc(),
      pushed: pushed,
      pulled: pulled,
      conflicts: conflicts,
      offline: false,
    );
  }

  Future<_PushOutcome> _pushOne(
    BusinessContext context,
    SyncOutboxEntry command,
  ) async {
    try {
      final result = await _commands.execute(
        command,
        payloadOverride: await _payloadFor(command),
      );
      if (result.operationId != command.operationId) {
        throw StateError('Remote operation ID did not match the outbox entry.');
      }
      await _outboxDao.markSucceeded(
        operationId: command.operationId,
        now: _clock.nowUtc(),
      );
      final version = _resultVersion(result.result);
      if (version != null) {
        await _versionDao.save(
          organizationId: context.organizationId,
          branchId: command.branchId,
          entityType: command.aggregateType,
          entityId: command.aggregateId,
          remoteVersion: version,
          operationId: command.operationId,
          updatedAt: _clock.nowUtc(),
        );
      }
      return _PushOutcome.succeeded;
    } catch (error, stackTrace) {
      final message = _safeError(error);
      if (_isConflict(error)) {
        await _recordConflict(context, command, message);
        return _PushOutcome.conflict;
      }
      final permanent = _isPermanent(error);
      final state = await _outboxDao.markFailed(
        operationId: command.operationId,
        error: message,
        now: _clock.nowUtc(),
        policy: permanent
            ? const OutboxRetryPolicy(maximumAttempts: 1)
            : const OutboxRetryPolicy(),
      );
      if (state == OutboxState.permanentFailure) {
        await _recordPermanentFailure(context, command, message);
      }
      _logger.warning(
        'Remote command failed and was retained in the outbox.',
        scope: 'sync.push',
        error: error,
        stackTrace: stackTrace,
      );
      return permanent ? _PushOutcome.permanentFailure : _PushOutcome.retry;
    }
  }

  Future<Map<String, Object?>> _payloadFor(SyncOutboxEntry command) async {
    final decoded = jsonDecode(command.payloadJson);
    if (decoded is! Map) {
      throw const FormatException('Outbox payload must be a JSON object.');
    }
    final payload = decoded.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    if (_requiresMasterVersion(command.commandType)) {
      payload['expectedVersion'] = await _versionDao.readVersion(
        organizationId: command.organizationId ?? '',
        entityType: command.aggregateType,
        entityId: command.aggregateId,
      );
    }
    return payload;
  }

  Future<int> _pullAndApply(BusinessContext context) async {
    final key = SyncCursorKey(
      scope: _cursorScope,
      organizationId: context.organizationId,
      branchId: context.branchId,
    );
    var cursor = (await _cursorDao.read(key))?.lastChangeSequence ?? 0;
    var applied = 0;
    for (
      var batchNumber = 0;
      batchNumber < _maximumPullBatches;
      batchNumber++
    ) {
      final changes = await _remote.pullChanges(
        organizationId: context.organizationId,
        branchId: context.branchId,
        afterSequence: cursor,
        limit: _pullBatchSize,
      );
      if (changes.isEmpty) break;
      await _database.transaction(() async {
        var nextCursor = cursor;
        for (final change in changes) {
          if (change.organizationId != context.organizationId ||
              (change.branchId != null &&
                  change.branchId != context.branchId)) {
            throw const FormatException(
              'Remote change is outside the requested scope.',
            );
          }
          await _applier.apply(change);
          await _versionDao.save(
            organizationId: change.organizationId,
            branchId: change.branchId,
            entityType: change.aggregateType,
            entityId: change.aggregateId,
            remoteVersion: change.version,
            operationId: change.operationId,
            updatedAt: change.occurredAt,
          );
          nextCursor = change.sequence;
        }
        await _cursorDao.save(
          key: key,
          lastChangeSequence: nextCursor,
          lastSyncedAt: _clock.nowUtc(),
        );
        cursor = nextCursor;
      });
      applied += changes.length;
      if (changes.length < _pullBatchSize) break;
    }
    return applied;
  }

  Future<void> _recordConflict(
    BusinessContext context,
    SyncOutboxEntry command,
    String reason,
  ) async {
    final now = _clock.nowUtc();
    final remoteVersion = await _versionDao.readVersion(
      organizationId: context.organizationId,
      entityType: command.aggregateType,
      entityId: command.aggregateId,
    );
    await _database.transaction(() async {
      await _outboxDao.markConflict(
        operationId: command.operationId,
        error: reason,
        now: now,
      );
      await _conflictDao.add(
        SyncConflictsCompanion.insert(
          id: 'conflict:${command.operationId}',
          operationId: command.operationId,
          organizationId: Value(context.organizationId),
          branchId: Value(context.branchId),
          actorUserId: Value(context.actorUserId),
          entityType: command.aggregateType,
          entityId: command.aggregateId,
          localPayloadJson: command.payloadJson,
          remotePayloadJson: jsonEncode({'remoteVersion': remoteVersion}),
          reason: reason,
          resolutionStatus: 'unresolved',
          createdAt: now,
        ),
      );
      if (command.aggregateType == 'sale') {
        await _setSaleRejected(command.aggregateId, context, reason);
      }
    });
  }

  Future<void> _recordPermanentFailure(
    BusinessContext context,
    SyncOutboxEntry command,
    String reason,
  ) async {
    await _database.transaction(() async {
      if (command.aggregateType == 'sale') {
        await _setSaleRejected(command.aggregateId, context, reason);
      }
      await _conflictDao.add(
        SyncConflictsCompanion.insert(
          id: 'conflict:${command.operationId}',
          operationId: command.operationId,
          organizationId: Value(context.organizationId),
          branchId: Value(context.branchId),
          actorUserId: Value(context.actorUserId),
          entityType: 'sale',
          entityId: command.aggregateId,
          localPayloadJson: command.payloadJson,
          remotePayloadJson: '{}',
          reason: reason,
          resolutionStatus: 'unresolved',
          createdAt: _clock.nowUtc(),
        ),
      );
    });
  }

  Future<void> _setSaleRejected(
    String saleId,
    BusinessContext context,
    String reason,
  ) async {
    await (_database.update(_database.sales)..where(
          (row) =>
              row.id.equals(saleId) &
              row.organizationId.equals(context.organizationId) &
              row.branchId.equals(context.branchId),
        ))
        .write(
          SalesCompanion(
            status: const Value('sync_rejected'),
            updatedAt: Value(_clock.nowUtc()),
          ),
        );
    _logger.warning(
      'A completed local sale was rejected by the remote backend: $reason',
      scope: 'sync.sale',
    );
  }

  bool _requiresMasterVersion(String type) {
    return const {
      'product.update',
      'product.archive',
      'product.restore',
      'category.update',
      'category.archive',
      'category.restore',
      'unit.update',
      'unit.archive',
      'unit.restore',
    }.contains(type);
  }

  bool _isConflict(Object error) {
    return error is FirebaseFunctionsException &&
        const {
          'aborted',
          'already-exists',
          'failed-precondition',
        }.contains(error.code);
  }

  bool _isPermanent(Object error) {
    return error is FormatException ||
        error is StateError ||
        (error is FirebaseFunctionsException &&
            const {
              'invalid-argument',
              'permission-denied',
              'not-found',
              'unauthenticated',
            }.contains(error.code));
  }

  int? _resultVersion(Object? value) {
    if (value is Map) {
      final version = value['version'];
      if (version is int) return version;
      for (final nested in value.values) {
        final found = _resultVersion(nested);
        if (found != null) return found;
      }
    }
    if (value is List) {
      for (final nested in value) {
        final found = _resultVersion(nested);
        if (found != null) return found;
      }
    }
    return null;
  }

  String _safeError(Object error) {
    if (error is FirebaseFunctionsException) {
      return '${error.code}: ${error.message ?? 'Remote command failed.'}';
    }
    return error.toString();
  }
}

enum _PushOutcome { succeeded, retry, permanentFailure, conflict }
