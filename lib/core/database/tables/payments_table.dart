import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'sales_table.dart';
import 'shifts_table.dart';

@TableIndex(
  name: 'payments_shift_idx',
  columns: {#organizationId, #branchId, #shiftId, #createdAt},
)
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.restrict)();
  TextColumn get shiftId =>
      text().nullable().references(Shifts, #id, onDelete: KeyAction.restrict)();
  TextColumn get paymentMethod => text()();
  IntColumn get tenderedAmountMinor => integer().check(
    const CustomExpression<bool>('tendered_amount_minor > 0'),
  )();
  IntColumn get appliedAmountMinor => integer().check(
    const CustomExpression<bool>('applied_amount_minor > 0'),
  )();
  IntColumn get changeAmountMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('change_amount_minor >= 0'))();
  TextColumn get reference => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {saleId, paymentMethod},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_id, organization_id, branch_id) '
        'REFERENCES sales (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (shift_id, organization_id, branch_id) '
        'REFERENCES shifts (id, organization_id, branch_id) ON DELETE RESTRICT',
    "CHECK (payment_method IN ('cash', 'card', 'e_wallet'))",
    'CHECK (tendered_amount_minor = applied_amount_minor + change_amount_minor)',
    "CHECK ((payment_method = 'cash') OR change_amount_minor = 0)",
  ];
}
