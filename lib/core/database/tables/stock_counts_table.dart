import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'stock_locations_table.dart';

@TableIndex(
  name: 'stock_counts_status_idx',
  columns: {#organizationId, #branchId, #stockLocationId, #status},
)
class StockCounts extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get stockLocationId =>
      text().references(StockLocations, #id, onDelete: KeyAction.restrict)();
  TextColumn get operationId => text()();
  TextColumn get completionOperationId => text().nullable()();
  TextColumn get countType => text()();
  TextColumn get status =>
      text().withDefault(const Constant<String>('in_progress'))();
  TextColumn get notes => text().nullable()();
  TextColumn get startedByUserId => text()();
  DateTimeColumn get startedAt => dateTime()();
  TextColumn get completedByUserId => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, operationId},
    {organizationId, completionOperationId},
    {id, organizationId},
    {id, organizationId, branchId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (stock_location_id, organization_id, branch_id) '
        'REFERENCES stock_locations (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    "CHECK (count_type IN ('full', 'cycle'))",
    "CHECK (status IN ('in_progress', 'completed', 'cancelled'))",
  ];
}
