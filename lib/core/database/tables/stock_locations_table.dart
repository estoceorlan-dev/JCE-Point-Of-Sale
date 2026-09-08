import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';

@TableIndex(
  name: 'stock_locations_branch_idx',
  columns: {#organizationId, #branchId, #isActive},
)
class StockLocations extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get locationType =>
      text().withDefault(const Constant<String>('warehouse'))();
  BoolColumn get isDefault =>
      boolean().withDefault(const Constant<bool>(false))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(true))();
  IntColumn get version => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, branchId, code},
    {id, organizationId, branchId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    "CHECK (location_type IN ('sales_floor', 'warehouse', 'returns', 'damaged'))",
  ];
}
