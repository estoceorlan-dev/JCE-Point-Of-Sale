import 'package:drift/drift.dart';

class SyncCursors extends Table {
  @override
  String get tableName => 'sync_cursors';

  TextColumn get cursorKey => text()();
  TextColumn get scope => text()();
  TextColumn get organizationId => text().nullable()();
  TextColumn get branchId => text().nullable()();
  TextColumn get projection => text().nullable()();
  TextColumn get permissionDigest => text().nullable()();
  TextColumn get actorUserId => text().nullable()();
  TextColumn get deviceId => text().nullable()();
  IntColumn get lastChangeSequence =>
      integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {cursorKey};
}
