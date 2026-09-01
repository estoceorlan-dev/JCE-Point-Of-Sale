import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'products_table.dart';
import 'stock_locations_table.dart';

@TableIndex(
  name: 'inventory_balances_low_stock_idx',
  columns: {#organizationId, #branchId, #stockLocationId, #onHandMilli},
)
class InventoryBalances extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get stockLocationId =>
      text().references(StockLocations, #id, onDelete: KeyAction.restrict)();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  IntColumn get onHandMilli => integer().withDefault(const Constant<int>(0))();
  IntColumn get reservedMilli => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('reserved_milli >= 0'))();
  IntColumn get reorderPointMilli => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('reorder_point_milli >= 0'))();
  IntColumn get weightedAverageCostMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(
        const CustomExpression<bool>('weighted_average_cost_minor >= 0'),
      )();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, branchId, stockLocationId, productId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (stock_location_id, organization_id, branch_id) '
        'REFERENCES stock_locations (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) '
        'REFERENCES products (id, organization_id) ON DELETE RESTRICT',
  ];
}
