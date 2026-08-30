import 'package:drift/drift.dart';

import 'approval_requests_table.dart';
import 'branches_table.dart';
import 'inventory_transactions_table.dart';
import 'organizations_table.dart';
import 'sales_table.dart';

@TableIndex(
  name: 'sale_returns_history_idx',
  columns: {#organizationId, #branchId, #completedAt},
)
class SaleReturns extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.restrict)();
  TextColumn get operationId => text()();
  TextColumn get returnNumber => text()();
  TextColumn get correctionType => text()();
  TextColumn get status =>
      text().withDefault(const Constant<String>('completed'))();
  TextColumn get reasonCode => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get inventoryTransactionId => text().nullable().references(
    InventoryTransactions,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get approvalRequestId => text().nullable().references(
    ApprovalRequests,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get subtotalMinor =>
      integer().check(const CustomExpression<bool>('subtotal_minor >= 0'))();
  IntColumn get discountMinor =>
      integer().check(const CustomExpression<bool>('discount_minor >= 0'))();
  IntColumn get taxMinor =>
      integer().check(const CustomExpression<bool>('tax_minor >= 0'))();
  IntColumn get totalMinor =>
      integer().check(const CustomExpression<bool>('total_minor > 0'))();
  TextColumn get createdByUserId => text()();
  TextColumn get approvedByUserId => text().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, operationId},
    {organizationId, branchId, returnNumber},
    {id, organizationId, branchId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_id, organization_id, branch_id) '
        'REFERENCES sales (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (inventory_transaction_id, organization_id, branch_id) '
        'REFERENCES inventory_transactions (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'FOREIGN KEY (approval_request_id, organization_id, branch_id) '
        'REFERENCES approval_requests (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    "CHECK (correction_type IN ('return', 'void'))",
    "CHECK (status IN ('completed', 'sync_rejected'))",
    'CHECK (discount_minor <= subtotal_minor)',
    'CHECK ((approval_request_id IS NULL AND approved_by_user_id IS NULL '
        'AND approved_at IS NULL) OR (approval_request_id IS NOT NULL '
        'AND approved_by_user_id IS NOT NULL AND approved_at IS NOT NULL))',
  ];
}
