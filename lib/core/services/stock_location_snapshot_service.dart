import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../shared/models/business_context.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../config/app_config.dart';
import '../remote/firebase_functions_provider.dart';
import '../sync/stock_location_change_applier.dart';

final stockLocationSnapshotServiceProvider =
    Provider<StockLocationSnapshotService>((ref) {
      const functionName = String.fromEnvironment(
        'JCE_STOCK_LOCATIONS_SNAPSHOT_FUNCTION',
        defaultValue: 'getStockLocationsSnapshot',
      );
      final functions = ref.watch(firebaseFunctionsProvider);
      return StockLocationSnapshotService(
        database: ref.watch(appDatabaseProvider),
        demoMode: ref.watch(appConfigProvider).enableDemoAuth,
        load: (context) async {
          final response = await functions.httpsCallable(functionName).call({
            'organizationId': context.organizationId,
            'branchId': context.branchId,
          });
          if (response.data is! Map) {
            throw const FormatException('Invalid location snapshot.');
          }
          return Map<String, Object?>.from(response.data as Map);
        },
      );
    });

class StockLocationSnapshotService {
  const StockLocationSnapshotService({
    required this.database,
    required this.load,
    required this.demoMode,
  });
  final AppDatabase database;
  final Future<Map<String, Object?>> Function(BusinessContext) load;
  final bool demoMode;

  Future<void> refresh(BusinessContext context) async {
    if (demoMode) return;
    final applier = StockLocationChangeApplier(database);
    if (await applier.hasPending(context.organizationId, context.branchId)) {
      return;
    }
    final rows = _rows(context, await load(context));
    await database.transaction(() async {
      if (await applier.hasPending(context.organizationId, context.branchId)) {
        return;
      }
      for (final row in rows) {
        await applier.applyRow(
          context.organizationId,
          context.branchId,
          row,
          DateTime.now().toUtc(),
          replaceLocal: true,
        );
      }
    });
  }

  Future<void> acceptRemote(
    BusinessContext context,
    SyncConflict conflict,
  ) async {
    if (demoMode ||
        conflict.entityType != 'stock_location' ||
        conflict.organizationId != context.organizationId ||
        conflict.branchId != context.branchId ||
        conflict.actorUserId != context.actorUserId) {
      throw StateError(
        'This location conflict is outside the signed-in branch/account.',
      );
    }
    final rows = _rows(context, await load(context));
    if (!rows.any((row) => row['id'] == conflict.entityId)) {
      throw StateError(
        'No remote location exists; the conflict remains unresolved.',
      );
    }
    await database.transaction(() async {
      final stored = await database.syncConflictDao.unresolvedForOperation(
        conflict.operationId,
      );
      if (stored?.id != conflict.id) {
        throw StateError('The conflict has already changed.');
      }
      final related =
          await (database.select(database.syncOutboxEntries)
                ..where(
                  (row) =>
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.aggregateType.equals('stock_location') &
                      row.operationId.equals(conflict.operationId).not() &
                      row.status.isNotIn(const ['succeeded', 'discarded']),
                )
                ..limit(1))
              .getSingleOrNull();
      if (related != null) {
        throw StateError(
          'Resolve other pending location changes before accepting the remote record.',
        );
      }
      final now = DateTime.now().toUtc();
      await database.outboxDao.discard(conflict.operationId, now);
      final applier = StockLocationChangeApplier(database);
      for (final row in rows) {
        await applier.applyRow(
          context.organizationId,
          context.branchId,
          row,
          now,
          replaceLocal: true,
        );
      }
      await database.syncConflictDao.resolve(
        id: conflict.id,
        resolutionStatus: 'accepted_remote',
        resolvedAt: now,
      );
    });
  }

  List<Map<String, Object?>> _rows(
    BusinessContext context,
    Map<String, Object?> value,
  ) {
    if (value['schemaVersion'] != 1 ||
        value['organizationId'] != context.organizationId ||
        value['branchId'] != context.branchId ||
        value['locations'] is! List) {
      throw const FormatException(
        'The stock location snapshot is outside the requested scope.',
      );
    }
    final rows = (value['locations'] as List)
        .map((row) => Map<String, Object?>.from(row as Map))
        .toList();
    if (rows.any(
          (row) =>
              row['organization_id'] != context.organizationId ||
              row['branch_id'] != context.branchId,
        ) ||
        rows.map((row) => row['id']).toSet().length != rows.length) {
      throw const FormatException('Invalid stock location snapshot records.');
    }
    return rows;
  }
}
