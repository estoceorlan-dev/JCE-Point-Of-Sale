import 'package:drift/drift.dart';

import '../app_database.dart';
import '../models/sync_cursor_key.dart';
import '../tables/sync_cursors_table.dart';

part 'sync_cursor_dao.g.dart';

@DriftAccessor(tables: [SyncCursors])
class SyncCursorDao extends DatabaseAccessor<AppDatabase>
    with _$SyncCursorDaoMixin {
  SyncCursorDao(super.attachedDatabase);

  Future<SyncCursor?> read(SyncCursorKey key) {
    return (select(syncCursors)
          ..where((row) => row.cursorKey.equals(key.value))
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<SyncCursor?> watch(SyncCursorKey key) {
    return (select(syncCursors)
          ..where((row) => row.cursorKey.equals(key.value))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<bool> existsForScope({
    required String scope,
    required String organizationId,
    required String branchId,
    required String projection,
    required String actorUserId,
    required String? deviceId,
  }) async {
    final row =
        await (select(syncCursors)
              ..where(
                (value) =>
                    value.scope.equals(scope) &
                    value.organizationId.equals(organizationId) &
                    value.branchId.equals(branchId) &
                    value.projection.equals(projection) &
                    value.actorUserId.equals(actorUserId) &
                    value.deviceId.equalsNullable(deviceId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> save({
    required SyncCursorKey key,
    required int lastChangeSequence,
    required DateTime lastSyncedAt,
  }) {
    return into(syncCursors).insertOnConflictUpdate(
      SyncCursorsCompanion.insert(
        cursorKey: key.value,
        scope: key.scope,
        organizationId: Value(key.organizationId),
        branchId: Value(key.branchId),
        projection: Value(key.projection),
        permissionDigest: Value(key.permissionDigest),
        actorUserId: Value(key.actorUserId),
        deviceId: Value(key.deviceId),
        lastChangeSequence: Value(lastChangeSequence),
        lastSyncedAt: Value(lastSyncedAt.toUtc()),
      ),
    );
  }
}
