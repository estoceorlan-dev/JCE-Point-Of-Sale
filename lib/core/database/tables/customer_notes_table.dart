import 'package:drift/drift.dart';

import 'app_users_table.dart';
import 'branches_table.dart';
import 'customers_table.dart';
import 'organizations_table.dart';

@TableIndex(
  name: 'customer_notes_history_idx',
  columns: {#organizationId, #customerId, #createdAt},
)
class CustomerNotes extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.restrict)();
  TextColumn get body => text()();
  TextColumn get createdByUserId =>
      text().references(AppUsers, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (customer_id, organization_id) '
        'REFERENCES customers (id, organization_id) ON DELETE RESTRICT',
  ];
}
