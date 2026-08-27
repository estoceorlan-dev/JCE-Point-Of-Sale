import 'package:drift/drift.dart';

import '../app_database.dart';
import '../models/outbox_command.dart';
import '../models/outbox_state.dart';
import '../models/sync_diagnostics.dart';
import '../outbox_retry_policy.dart';
import '../tables/sync_outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [SyncOutboxEntries])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.attachedDatabase);

  Future<void> enqueue(OutboxCommand command) {
    return into(syncOutboxEntries).insert(
      SyncOutboxEntriesCompanion.insert(
        operationId: command.operationId,
        organizationId: Value(command.organizationId),
        branchId: Value(command.branchId),
        actorUserId: Value(command.actorUserId),
        commandType: command.commandType,
        aggregateType: command.aggregateType,
        aggregateId: command.aggregateId,
        payloadJson: command.payloadJson,
        status: command.state.databaseValue,
        createdAt: command.createdAt.toUtc(),
        updatedAt: command.createdAt.toUtc(),
      ),
    );
  }

  Stream<int> watchPendingCount() {
    final count = syncOutboxEntries.operationId.count();
    final query = selectOnly(syncOutboxEntries)
      ..addColumns([count])
      ..where(
        syncOutboxEntries.status.isIn([
          OutboxState.pending.databaseValue,
          OutboxState.processing.databaseValue,
          OutboxState.retryableFailure.databaseValue,
        ]),
      );

    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<int> pendingCount() async {
    return watchPendingCount().first;
  }

  Future<List<SyncOutboxEntry>> claimEligibleBatch({
    required DateTime now,
    String? organizationId,
    String? branchId,
    String? actorUserId,
    int limit = 25,
  }) {
    return transaction(() async {
      final utcNow = now.toUtc();
      final query = select(syncOutboxEntries)
        ..where(
          (row) =>
              row.status.equals(OutboxState.pending.databaseValue) |
              (row.status.equals(OutboxState.retryableFailure.databaseValue) &
                  (row.nextAttemptAt.isNull() |
                      row.nextAttemptAt.isSmallerOrEqualValue(utcNow))),
        );

      if (organizationId != null) {
        query.where((row) => row.organizationId.equals(organizationId));
      }
      if (branchId != null) {
        query.where((row) => row.branchId.equals(branchId));
      }
      if (actorUserId != null) {
        query.where(
          (row) =>
              row.actorUserId.isNull() | row.actorUserId.equals(actorUserId),
        );
      }
      query
        ..orderBy([
          (row) => OrderingTerm.asc(row.createdAt),
          (row) => OrderingTerm.asc(row.operationId),
        ])
        ..limit(limit * 10);

      final eligible = await query.get();
      final entries = <SyncOutboxEntry>[];
      final claimedAggregates = <String>{};
      for (final entry in eligible) {
        final aggregateKey =
            '${entry.organizationId}|${entry.branchId}|'
            '${entry.aggregateType}|${entry.aggregateId}';
        if (!claimedAggregates.add(aggregateKey)) {
          continue;
        }
        final olderBlocker =
            await (select(syncOutboxEntries)
                  ..where(
                    (row) =>
                        row.organizationId.equalsNullable(
                          entry.organizationId,
                        ) &
                        row.branchId.equalsNullable(entry.branchId) &
                        row.aggregateType.equals(entry.aggregateType) &
                        row.aggregateId.equals(entry.aggregateId) &
                        row.status.isNotIn([
                          OutboxState.succeeded.databaseValue,
                          OutboxState.discarded.databaseValue,
                        ]) &
                        (row.createdAt.isSmallerThanValue(entry.createdAt) |
                            (row.createdAt.equals(entry.createdAt) &
                                row.operationId.isSmallerThanValue(
                                  entry.operationId,
                                ))),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (olderBlocker == null) {
          entries.add(entry);
        }
        if (entries.length == limit) {
          break;
        }
      }
      for (final entry in entries) {
        await (update(
          syncOutboxEntries,
        )..where((row) => row.operationId.equals(entry.operationId))).write(
          SyncOutboxEntriesCompanion(
            status: Value(OutboxState.processing.databaseValue),
            attemptCount: Value(entry.attemptCount + 1),
            actorUserId: actorUserId == null
                ? const Value.absent()
                : Value(entry.actorUserId ?? actorUserId),
            updatedAt: Value(utcNow),
          ),
        );
      }

      return entries
          .map(
            (entry) => entry.copyWith(
              status: OutboxState.processing.databaseValue,
              attemptCount: entry.attemptCount + 1,
              actorUserId: Value(entry.actorUserId ?? actorUserId),
              updatedAt: utcNow,
            ),
          )
          .toList(growable: false);
    });
  }

  Stream<SyncDiagnostics> watchDiagnostics({
    required String organizationId,
    required String branchId,
    required String actorUserId,
  }) {
    final query = select(syncOutboxEntries)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            row.branchId.equals(branchId) &
            (row.actorUserId.isNull() | row.actorUserId.equals(actorUserId)) &
            row.status.isNotIn([
              OutboxState.succeeded.databaseValue,
              OutboxState.discarded.databaseValue,
            ]),
      );
    return query.watch().map((rows) {
      int count(OutboxState state) =>
          rows.where((row) => row.status == state.databaseValue).length;
      return SyncDiagnostics(
        pending: count(OutboxState.pending),
        processing: count(OutboxState.processing),
        retrying: count(OutboxState.retryableFailure),
        failed: count(OutboxState.permanentFailure),
        conflicted: count(OutboxState.conflict),
      );
    });
  }

  Future<int> pendingCountFor({
    required String organizationId,
    required String branchId,
    required String actorUserId,
  }) async {
    final count = syncOutboxEntries.operationId.count();
    final query = selectOnly(syncOutboxEntries)
      ..addColumns([count])
      ..where(
        syncOutboxEntries.organizationId.equals(organizationId) &
            syncOutboxEntries.branchId.equals(branchId) &
            (syncOutboxEntries.actorUserId.isNull() |
                syncOutboxEntries.actorUserId.equals(actorUserId)) &
            syncOutboxEntries.commandType.equals('device.register').not() &
            syncOutboxEntries.status.isNotIn([
              OutboxState.succeeded.databaseValue,
              OutboxState.discarded.databaseValue,
            ]),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<int> markConflict({
    required String operationId,
    required String error,
    required DateTime now,
  }) {
    return _setTerminalState(
      operationId: operationId,
      state: OutboxState.conflict,
      error: error,
      now: now,
    );
  }

  Future<int> retry(String operationId, DateTime now) {
    return (update(
      syncOutboxEntries,
    )..where((row) => row.operationId.equals(operationId))).write(
      SyncOutboxEntriesCompanion(
        status: Value(OutboxState.pending.databaseValue),
        attemptCount: const Value(0),
        nextAttemptAt: Value(now.toUtc()),
        lastError: const Value(null),
        updatedAt: Value(now.toUtc()),
      ),
    );
  }

  Future<int> discard(String operationId, DateTime now) {
    return _setTerminalState(
      operationId: operationId,
      state: OutboxState.discarded,
      error: null,
      now: now,
    );
  }

  Future<int> _setTerminalState({
    required String operationId,
    required OutboxState state,
    required String? error,
    required DateTime now,
  }) {
    return (update(
      syncOutboxEntries,
    )..where((row) => row.operationId.equals(operationId))).write(
      SyncOutboxEntriesCompanion(
        status: Value(state.databaseValue),
        nextAttemptAt: const Value(null),
        lastError: Value(error),
        updatedAt: Value(now.toUtc()),
      ),
    );
  }

  Future<int> markSucceeded({
    required String operationId,
    required DateTime now,
  }) {
    return (update(
      syncOutboxEntries,
    )..where((row) => row.operationId.equals(operationId))).write(
      SyncOutboxEntriesCompanion(
        status: Value(OutboxState.succeeded.databaseValue),
        nextAttemptAt: const Value(null),
        lastError: const Value(null),
        updatedAt: Value(now.toUtc()),
      ),
    );
  }

  Future<OutboxState?> markFailed({
    required String operationId,
    required String error,
    required DateTime now,
    OutboxRetryPolicy policy = const OutboxRetryPolicy(),
  }) async {
    final entry = await (select(
      syncOutboxEntries,
    )..where((row) => row.operationId.equals(operationId))).getSingleOrNull();
    if (entry == null) {
      return null;
    }

    final state = policy.isPermanentFailure(entry.attemptCount)
        ? OutboxState.permanentFailure
        : OutboxState.retryableFailure;
    final nextAttemptAt = state == OutboxState.retryableFailure
        ? now.toUtc().add(policy.delayForAttempt(entry.attemptCount))
        : null;

    await (update(
      syncOutboxEntries,
    )..where((row) => row.operationId.equals(operationId))).write(
      SyncOutboxEntriesCompanion(
        status: Value(state.databaseValue),
        nextAttemptAt: Value(nextAttemptAt),
        lastError: Value(error),
        updatedAt: Value(now.toUtc()),
      ),
    );
    return state;
  }

  Future<int> recoverStaleProcessing({
    required DateTime staleBefore,
    required DateTime now,
  }) {
    return (update(syncOutboxEntries)..where(
          (row) =>
              row.status.equals(OutboxState.processing.databaseValue) &
              row.updatedAt.isSmallerThanValue(staleBefore.toUtc()),
        ))
        .write(
          SyncOutboxEntriesCompanion(
            status: Value(OutboxState.pending.databaseValue),
            nextAttemptAt: Value(now.toUtc()),
            lastError: const Value('Recovered stale processing operation.'),
            updatedAt: Value(now.toUtc()),
          ),
        );
  }
}
