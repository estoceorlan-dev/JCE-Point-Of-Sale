import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/outbox_dao.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/services/backend_sync_service.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/logout_readiness.dart';
import '../../domain/repositories/session_exit_repository.dart';

class OfflineFirstSessionExitRepository implements SessionExitRepository {
  const OfflineFirstSessionExitRepository({
    required AppDatabase database,
    required OutboxDao outboxDao,
    required BackendSyncService syncService,
  }) : _database = database,
       _outboxDao = outboxDao,
       _syncService = syncService;

  final AppDatabase _database;
  final OutboxDao _outboxDao;
  final BackendSyncService _syncService;

  @override
  Future<Result<LogoutReadiness, Failure>> prepareLogout({
    required BusinessContext context,
  }) async {
    try {
      // Best effort: offline is a valid result, while successful reachability
      // gives queued work one final chance to complete.
      await _syncService.synchronize(
        context: context,
        trigger: SyncTrigger.manual,
      );
      final openShiftCount = _database.shifts.id.count();
      final openShiftQuery = _database.selectOnly(_database.shifts)
        ..addColumns([openShiftCount])
        ..where(
          _database.shifts.organizationId.equals(context.organizationId) &
              _database.shifts.branchId.equals(context.branchId) &
              _database.shifts.openedByUserId.equals(context.actorUserId) &
              _database.shifts.status.equals('open'),
        );
      final recoveryCount = _database.posCarts.id.count();
      final recoveryQuery = _database.selectOnly(_database.posCarts)
        ..addColumns([recoveryCount])
        ..where(
          _database.posCarts.organizationId.equals(context.organizationId) &
              _database.posCarts.branchId.equals(context.branchId) &
              _database.posCarts.ownerUserId.equals(context.actorUserId) &
              _database.posCarts.checkoutOperationId.isNotNull(),
        );
      return Result.success(
        LogoutReadiness(
          openShiftCount:
              (await openShiftQuery.getSingle()).read(openShiftCount) ?? 0,
          checkoutRecoveryCount:
              (await recoveryQuery.getSingle()).read(recoveryCount) ?? 0,
          pendingOperationalCommandCount: await _outboxDao.pendingCountFor(
            organizationId: context.organizationId,
            branchId: context.branchId,
            actorUserId: context.actorUserId,
          ),
        ),
      );
    } catch (error, stackTrace) {
      return Result.failure(FailureMapper.fromException(error, stackTrace));
    }
  }
}
