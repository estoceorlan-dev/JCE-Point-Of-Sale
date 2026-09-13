import 'package:drift/drift.dart';

@TableIndex(
  name: 'sync_snapshot_staging_scope_idx',
  columns: {#organizationId, #branchId, #snapshotToken, #collection},
)
class SyncSnapshotStagingRecords extends Table {
  TextColumn get snapshotToken => text()();
  TextColumn get organizationId => text()();
  TextColumn get branchId => text()();
  TextColumn get collection => text()();
  TextColumn get recordId => text()();
  TextColumn get payloadJson => text()();
  TextColumn get pageChecksum => text()();
  IntColumn get watermark => integer()();
  DateTimeColumn get stagedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {snapshotToken, collection, recordId};
}
