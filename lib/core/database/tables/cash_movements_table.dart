import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'registers_table.dart';
import 'shifts_table.dart';

@TableIndex(
  name: 'cash_movements_shift_idx',
  columns: {#organizationId, #branchId, #shiftId, #occurredAt},
)
class CashMovements extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get registerId =>
      text().references(Registers, #id, onDelete: KeyAction.restrict)();
  TextColumn get shiftId =>
      text().references(Shifts, #id, onDelete: KeyAction.restrict)();
  TextColumn get operationId => text()();
  TextColumn get movementType => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get reason => text()();
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
    "CHECK (movement_type IN ('cash_in', 'cash_out', 'payout', 'correction'))",
    "CHECK ((movement_type = 'cash_in' AND amount_minor > 0) "
        "OR (movement_type IN ('cash_out', 'payout') AND amount_minor < 0) "
        "OR (movement_type = 'correction' AND amount_minor <> 0))",
  ];
}
