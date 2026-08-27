import 'package:drift/drift.dart';

class SyncOutboxEntries extends Table {
  @override
  String get tableName => 'sync_outbox';

  TextColumn get operationId => text()();
  TextColumn get organizationId => text().nullable()();
  TextColumn get branchId => text().nullable()();
  TextColumn get actorUserId => text().nullable()();
  TextColumn get commandType => text()();
  TextColumn get aggregateType => text()();
  TextColumn get aggregateId => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};
}
