import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/models/outbox_command.dart';
import 'package:jce_pos/core/database/models/outbox_state.dart';
import 'package:jce_pos/core/database/outbox_retry_policy.dart';
import 'package:path/path.dart' as path;

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('claims eligible commands in creation order', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await database.outboxDao.enqueue(_command('operation-2', now));
    await database.outboxDao.enqueue(
      _command('operation-1', now.subtract(const Duration(minutes: 1))),
    );

    final claimed = await database.outboxDao.claimEligibleBatch(
      now: now,
      limit: 1,
    );

    expect(claimed, hasLength(1));
    expect(claimed.single.operationId, 'operation-1');
    expect(claimed.single.status, OutboxState.processing.databaseValue);
    expect(claimed.single.attemptCount, 1);
    expect(await database.outboxDao.pendingCount(), 2);
  });

  test('retry scheduling uses bounded exponential backoff', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    const policy = OutboxRetryPolicy(
      baseDelay: Duration(seconds: 10),
      maximumDelay: Duration(seconds: 25),
      maximumAttempts: 3,
    );
    await database.outboxDao.enqueue(_command('operation-1', now));

    await database.outboxDao.claimEligibleBatch(now: now);
    final firstState = await database.outboxDao.markFailed(
      operationId: 'operation-1',
      error: 'Network unavailable.',
      now: now,
      policy: policy,
    );
    var row = await database.select(database.syncOutboxEntries).getSingle();

    expect(firstState, OutboxState.retryableFailure);
    expect(row.createdAt.isUtc, isTrue);
    expect(row.nextAttemptAt?.isUtc, isTrue);
    expect(row.nextAttemptAt, now.add(const Duration(seconds: 10)));

    await database.outboxDao.claimEligibleBatch(
      now: now.add(const Duration(seconds: 10)),
    );
    await database.outboxDao.markFailed(
      operationId: 'operation-1',
      error: 'Still unavailable.',
      now: now.add(const Duration(seconds: 10)),
      policy: policy,
    );
    row = await database.select(database.syncOutboxEntries).getSingle();
    expect(row.nextAttemptAt, now.add(const Duration(seconds: 30)));

    await database.outboxDao.claimEligibleBatch(
      now: now.add(const Duration(seconds: 30)),
    );
    final finalState = await database.outboxDao.markFailed(
      operationId: 'operation-1',
      error: 'Rejected.',
      now: now.add(const Duration(seconds: 30)),
      policy: policy,
    );
    row = await database.select(database.syncOutboxEntries).getSingle();

    expect(finalState, OutboxState.permanentFailure);
    expect(row.nextAttemptAt, isNull);
  });

  test('dependent commands wait for their prerequisite to succeed', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await database.outboxDao.enqueue(_command('sale-operation', now));
    await database.outboxDao.enqueue(
      _command(
        'return-operation',
        now.add(const Duration(seconds: 1)),
        dependsOnOperationId: 'sale-operation',
      ),
    );

    final first = await database.outboxDao.claimEligibleBatch(now: now);
    expect(first.map((entry) => entry.operationId), ['sale-operation']);
    await database.outboxDao.markSucceeded(
      operationId: 'sale-operation',
      now: now,
    );
    final second = await database.outboxDao.claimEligibleBatch(
      now: now.add(const Duration(seconds: 2)),
    );
    expect(second.map((entry) => entry.operationId), ['return-operation']);
  });

  test('stale processing commands are returned to pending', () async {
    final startedAt = DateTime.utc(2026, 1, 1, 12);
    await database.outboxDao.enqueue(_command('operation-1', startedAt));
    await database.outboxDao.claimEligibleBatch(now: startedAt);

    final recovered = await database.outboxDao.recoverStaleProcessing(
      staleBefore: startedAt.add(const Duration(minutes: 5)),
      now: startedAt.add(const Duration(minutes: 10)),
    );
    final row = await database.select(database.syncOutboxEntries).getSingle();

    expect(recovered, 1);
    expect(row.status, OutboxState.pending.databaseValue);
  });

  test('reopening the database recovers processing commands', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('jce_outbox_test');
    final file = File(path.join(directory.path, 'restart.sqlite'));
    final startedAt = DateTime.utc(2026, 1, 1, 12);
    final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));

    await firstDatabase.outboxDao.enqueue(_command('operation-1', startedAt));
    await firstDatabase.outboxDao.claimEligibleBatch(now: startedAt);
    await firstDatabase.close();

    final reopenedDatabase = AppDatabase.forTesting(NativeDatabase(file));
    final row = await reopenedDatabase
        .select(reopenedDatabase.syncOutboxEntries)
        .getSingle();

    expect(row.status, OutboxState.pending.databaseValue);

    await reopenedDatabase.close();
    await directory.delete(recursive: true);
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });
}

OutboxCommand _command(
  String operationId,
  DateTime createdAt, {
  String? dependsOnOperationId,
}) {
  return OutboxCommand(
    operationId: operationId,
    organizationId: 'org-1',
    branchId: 'branch-1',
    commandType: 'test_command',
    aggregateType: 'test',
    aggregateId: operationId,
    dependsOnOperationId: dependsOnOperationId,
    payload: const {'test': true},
    createdAt: createdAt,
  );
}
