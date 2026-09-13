import 'package:drift/drift.dart';

import 'sync_outbox_table.dart';

class SyncOutboxDependencies extends Table {
  TextColumn get operationId => text().references(
    SyncOutboxEntries,
    #operationId,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get dependsOnOperationId => text().references(
    SyncOutboxEntries,
    #operationId,
    onDelete: KeyAction.restrict,
  )();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {operationId, dependsOnOperationId};
}
