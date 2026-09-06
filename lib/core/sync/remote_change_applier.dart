import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../remote/remote_sync_data_source.dart';
import 'catalog_change_applier.dart';
import 'operations_change_applier.dart';
import 'remote_change_envelope.dart';

abstract interface class RemoteChangeApplier {
  Future<void> apply(RemoteChange change);
}

class DriftRemoteChangeApplier implements RemoteChangeApplier {
  DriftRemoteChangeApplier(AppDatabase database)
    : _database = database,
      _catalog = CatalogChangeApplier(database),
      _operations = OperationsChangeApplier(database);

  final CatalogChangeApplier _catalog;
  final AppDatabase _database;
  final OperationsChangeApplier _operations;

  @override
  Future<void> apply(RemoteChange change) async {
    if (const {
      'branch',
      'app_user',
      'role',
      'register',
      'tax_category',
    }.contains(change.aggregateType)) {
      final pending =
          await (_database.select(_database.syncOutboxEntries)
                ..where(
                  (row) =>
                      row.organizationId.equals(change.organizationId) &
                      row.aggregateType.equals(change.aggregateType) &
                      row.aggregateId.equals(change.aggregateId) &
                      row.status.isIn(const [
                        'pending',
                        'processing',
                        'retryable_failure',
                        'permanent_failure',
                        'conflict',
                      ]),
                )
                ..limit(1))
              .getSingleOrNull();
      if (pending != null) return;
      final knownVersion = await _database.syncEntityVersionDao.readVersion(
        organizationId: change.organizationId,
        entityType: change.aggregateType,
        entityId: change.aggregateId,
      );
      if (change.version < knownVersion) return;
      final snapshotVersion = await _database.metadataDao.readValue(
        'admin_snapshot_version:${change.organizationId}:${change.aggregateType}:${change.aggregateId}',
      );
      if (snapshotVersion != null &&
          change.version <= int.parse(snapshotVersion)) {
        return;
      }
    }
    final envelope = RemoteChangeEnvelope.parse(change);
    if (await _catalog.apply(envelope)) return;
    if (await _operations.apply(envelope)) return;
    throw FormatException(
      'Unsupported remote command ${envelope.commandType}.',
    );
  }
}
