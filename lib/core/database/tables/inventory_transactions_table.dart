import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';

@TableIndex(
  name: 'inventory_transactions_history_idx',
  columns: {#organizationId, #branchId, #occurredAt},
)
class InventoryTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get operationId => text()();
  TextColumn get transactionType => text()();
  TextColumn get status =>
      text().withDefault(const Constant<String>('posted'))();
  TextColumn get reasonCode => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get referenceType => text().nullable()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get reversesTransactionId => text().nullable().references(
    InventoryTransactions,
    #id,
    onDelete: KeyAction.restrict,
  )();
  BoolColumn get occurredDuringStockCount =>
      boolean().withDefault(const Constant<bool>(false))();
  TextColumn get createdByUserId => text()();
  TextColumn get approvedByUserId => text().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, operationId},
    {id, organizationId, branchId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    "CHECK (status IN ('posted', 'reversed'))",
    "CHECK (transaction_type IN ('opening_balance', 'purchase_receipt', "
        "'sale', 'sale_return', 'adjustment_increase', 'adjustment_decrease', "
        "'transfer_shipment', 'transfer_receipt', 'stock_count_correction', "
        "'reversal'))",
  ];
}
