import 'package:drift/drift.dart';

import 'app_users_table.dart';
import 'branches_table.dart';
import 'loyalty_accounts_table.dart';
import 'organizations_table.dart';
import 'sales_table.dart';

@TableIndex(
  name: 'loyalty_ledger_history_idx',
  columns: {#organizationId, #accountId, #occurredAt},
)
class LoyaltyLedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId => text().nullable().references(
    Branches,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get accountId =>
      text().references(LoyaltyAccounts, #id, onDelete: KeyAction.restrict)();
  TextColumn get saleId =>
      text().nullable().references(Sales, #id, onDelete: KeyAction.restrict)();
  TextColumn get operationId => text()();
  TextColumn get entryType => text()();
  IntColumn get pointsDelta =>
      integer().check(const CustomExpression<bool>('points_delta <> 0'))();
  IntColumn get balanceAfter =>
      integer().check(const CustomExpression<bool>('balance_after >= 0'))();
  TextColumn get reason => text()();
  TextColumn get referenceType => text().nullable()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get createdByUserId =>
      text().references(AppUsers, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, operationId},
  ];

  @override
  List<String> get customConstraints => const [
    "CHECK (entry_type IN ('earn', 'redeem', 'adjustment', 'expiry', "
        "'reversal', 'merge_in', 'merge_out'))",
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (account_id, organization_id) '
        'REFERENCES loyalty_accounts (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_id, organization_id, branch_id) '
        'REFERENCES sales (id, organization_id, branch_id) ON DELETE RESTRICT',
  ];
}
