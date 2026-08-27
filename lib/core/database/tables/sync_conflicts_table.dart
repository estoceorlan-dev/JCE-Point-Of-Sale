import 'package:drift/drift.dart';

class SyncConflicts extends Table {
  @override
  String get tableName => 'sync_conflicts';

  TextColumn get id => text()();
  TextColumn get operationId => text()();
  TextColumn get organizationId => text().nullable()();
  TextColumn get branchId => text().nullable()();
  TextColumn get actorUserId => text().nullable()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get localPayloadJson => text()();
  TextColumn get remotePayloadJson => text()();
  TextColumn get reason => text()();
  TextColumn get resolutionStatus => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
