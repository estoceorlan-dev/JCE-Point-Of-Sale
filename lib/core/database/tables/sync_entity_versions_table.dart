import 'package:drift/drift.dart';

class SyncEntityVersions extends Table {
  @override
  String get tableName => 'sync_entity_versions';

  TextColumn get entityKey => text()();
  TextColumn get organizationId => text()();
  TextColumn get branchId => text().nullable()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get remoteVersion => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('remote_version >= 0'))();
  TextColumn get lastOperationId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {entityKey};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, entityType, entityId},
  ];
}
