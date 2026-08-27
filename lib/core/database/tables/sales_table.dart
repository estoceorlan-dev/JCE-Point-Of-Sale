import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'inventory_transactions_table.dart';
import 'organizations_table.dart';
import 'registers_table.dart';
import 'shifts_table.dart';

@TableIndex(
  name: 'sales_history_idx',
  columns: {#organizationId, #branchId, #completedAt},
)
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get registerId =>
      text().references(Registers, #id, onDelete: KeyAction.restrict)();
  TextColumn get shiftId =>
      text().nullable().references(Shifts, #id, onDelete: KeyAction.restrict)();
  TextColumn get inventoryTransactionId => text().nullable().references(
    InventoryTransactions,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get operationId => text()();
  TextColumn get receiptNumber => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant<String>('draft'))();
  TextColumn get cashierUserId => text()();
  IntColumn get subtotalMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('subtotal_minor >= 0'))();
  IntColumn get discountMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('discount_minor >= 0'))();
  IntColumn get taxMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('tax_minor >= 0'))();
  IntColumn get totalMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('total_minor >= 0'))();
  IntColumn get tenderedMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('tendered_minor >= 0'))();
  IntColumn get changeMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('change_minor >= 0'))();
  TextColumn get discountApprovedByUserId => text().nullable()();
  DateTimeColumn get discountApprovedAt => dateTime().nullable()();
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
    {organizationId, branchId, receiptNumber},
    {id, organizationId, branchId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (register_id, organization_id, branch_id) '
        'REFERENCES registers (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'FOREIGN KEY (shift_id, organization_id, branch_id) '
        'REFERENCES shifts (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'FOREIGN KEY (inventory_transaction_id, organization_id, branch_id) '
        'REFERENCES inventory_transactions (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    "CHECK (status IN ('draft', 'completed', 'voided', 'partially_returned', "
        "'returned', 'sync_rejected'))",
    "CHECK ((status = 'draft' AND completed_at IS NULL) OR "
        "(status <> 'draft' AND completed_at IS NOT NULL))",
    'CHECK (discount_minor <= subtotal_minor)',
  ];
}
