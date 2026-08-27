import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_entity_versions_table.dart';

part 'sync_entity_version_dao.g.dart';

@DriftAccessor(tables: [SyncEntityVersions])
class SyncEntityVersionDao extends DatabaseAccessor<AppDatabase>
    with _$SyncEntityVersionDaoMixin {
  SyncEntityVersionDao(super.attachedDatabase);

  static String key(String organizationId, String entityType, String entityId) {
    return '$organizationId::$entityType::$entityId';
  }

  Future<int> readVersion({
    required String organizationId,
    required String entityType,
    required String entityId,
  }) async {
    final row =
        await (select(syncEntityVersions)..where(
              (value) => value.entityKey.equals(
                key(organizationId, entityType, entityId),
              ),
            ))
            .getSingleOrNull();
    return row?.remoteVersion ?? 0;
  }

  Future<void> save({
    required String organizationId,
    required String? branchId,
    required String entityType,
    required String entityId,
    required int remoteVersion,
    required String operationId,
    required DateTime updatedAt,
  }) {
    return into(syncEntityVersions).insertOnConflictUpdate(
      SyncEntityVersionsCompanion.insert(
        entityKey: key(organizationId, entityType, entityId),
        organizationId: organizationId,
        branchId: Value(branchId),
        entityType: entityType,
        entityId: entityId,
        remoteVersion: Value(remoteVersion),
        lastOperationId: Value(operationId),
        updatedAt: updatedAt.toUtc(),
      ),
    );
  }
}
