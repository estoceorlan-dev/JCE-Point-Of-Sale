import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'shifts_table.dart';

class ShiftCounts extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get shiftId =>
      text().references(Shifts, #id, onDelete: KeyAction.restrict)();
  TextColumn get paymentMethod => text()();
  IntColumn get expectedAmountMinor => integer()();
  IntColumn get countedAmountMinor => integer().check(
    const CustomExpression<bool>('counted_amount_minor >= 0'),
  )();
  IntColumn get discrepancyMinor => integer()();
  TextColumn get countedByUserId => text()();
  DateTimeColumn get countedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {shiftId, paymentMethod},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (shift_id, organization_id, branch_id) '
        'REFERENCES shifts (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    "CHECK (payment_method IN ('cash', 'card', 'e_wallet'))",
    'CHECK (discrepancy_minor = counted_amount_minor - expected_amount_minor)',
  ];
}
