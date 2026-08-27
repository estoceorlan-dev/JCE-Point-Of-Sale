import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/audit_log_entry.dart';
import '../error/failure.dart';
import '../error/failures.dart';
import '../error/result.dart';
import 'app_database.dart';
import 'database_provider.dart';
import 'models/outbox_command.dart';

final localMutationTransactionProvider = Provider<LocalMutationTransaction>((
  ref,
) {
  return LocalMutationTransaction(ref.watch(appDatabaseProvider));
});

class LocalMutationTransaction {
  const LocalMutationTransaction(this._database);

  final AppDatabase _database;

  Future<Result<T, Failure>> execute<T>({
    required Future<T> Function(AppDatabase database) businessWrite,
    required AuditLogEntry auditEntry,
    required OutboxCommand outboxCommand,
  }) async {
    if (auditEntry.operationId != null &&
        auditEntry.operationId != outboxCommand.operationId) {
      return const Result.failure(
        ValidationFailure(
          'Audit and outbox operation IDs must refer to the same operation.',
        ),
      );
    }

    try {
      final value = await _database.transaction(() async {
        final result = await businessWrite(_database);
        await _database.auditLogDao.append(auditEntry);
        await _database.outboxDao.enqueue(outboxCommand);
        return result;
      });
      return Result.success(value);
    } catch (error, stackTrace) {
      if (error is Failure) {
        return Result.failure(error);
      }
      return Result.failure(
        DatabaseFailure(
          'The local mutation could not be saved atomically.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
