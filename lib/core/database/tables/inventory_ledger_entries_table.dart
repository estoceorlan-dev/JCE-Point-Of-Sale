import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'inventory_transactions_table.dart';
import 'organizations_table.dart';
import 'products_table.dart';
import 'stock_locations_table.dart';

@TableIndex(
  name: 'inventory_ledger_product_history_idx',
  columns: {#organizationId, #branchId, #productId, #occurredAt},
)
class InventoryLedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get transactionId => text().references(
    InventoryTransactions,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get stockLocationId =>
      text().references(StockLocations, #id, onDelete: KeyAction.restrict)();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  IntColumn get quantityDeltaMilli => integer().check(
    const CustomExpression<bool>('quantity_delta_milli <> 0'),
  )();
  IntColumn get balanceAfterMilli => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {transactionId, stockLocationId, productId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (transaction_id, organization_id, branch_id) '
        'REFERENCES inventory_transactions (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'FOREIGN KEY (stock_location_id, organization_id, branch_id) '
        'REFERENCES stock_locations (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) '
        'REFERENCES products (id, organization_id) ON DELETE RESTRICT',
  ];
}
