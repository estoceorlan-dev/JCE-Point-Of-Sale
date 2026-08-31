import 'package:drift/drift.dart';

import 'app_users_table.dart';
import 'organizations_table.dart';
import 'stock_transfers_table.dart';

@TableIndex(
  name: 'transfer_events_history_idx',
  columns: {#organizationId, #transferId, #occurredAt},
)
class TransferEvents extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get transferId =>
      text().references(StockTransfers, #id, onDelete: KeyAction.restrict)();
  TextColumn get operationId => text().unique()();
  TextColumn get eventType => text()();
  TextColumn get fromStatus => text().nullable()();
  TextColumn get toStatus => text()();
  TextColumn get actorUserId =>
      text().references(AppUsers, #id, onDelete: KeyAction.restrict)();
  TextColumn get reason => text().nullable()();
  TextColumn get metadataJson =>
      text().withDefault(const Constant<String>('{}'))();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (transfer_id, organization_id) '
        'REFERENCES stock_transfers (id, organization_id) ON DELETE RESTRICT',
  ];
}
