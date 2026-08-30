import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'cash_movements_table.dart';
import 'organizations_table.dart';
import 'sale_returns_table.dart';
import 'shifts_table.dart';

class RefundPayments extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get saleReturnId =>
      text().references(SaleReturns, #id, onDelete: KeyAction.restrict)();
  TextColumn get shiftId =>
      text().nullable().references(Shifts, #id, onDelete: KeyAction.restrict)();
  TextColumn get cashMovementId => text().nullable().references(
    CashMovements,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get refundMethod => text()();
  IntColumn get amountMinor =>
      integer().check(const CustomExpression<bool>('amount_minor > 0'))();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {saleReturnId, refundMethod},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_return_id, organization_id, branch_id) '
        'REFERENCES sale_returns (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'FOREIGN KEY (shift_id, organization_id, branch_id) '
        'REFERENCES shifts (id, organization_id, branch_id) ON DELETE RESTRICT',
    "CHECK (refund_method IN ('cash', 'card', 'e_wallet', 'store_credit'))",
    'CHECK ((refund_method = \'cash\' AND shift_id IS NOT NULL AND '
        'cash_movement_id IS NOT NULL) OR (refund_method <> \'cash\' AND '
        'cash_movement_id IS NULL))',
  ];
}
