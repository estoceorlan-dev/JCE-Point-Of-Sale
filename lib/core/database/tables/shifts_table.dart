import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'registers_table.dart';

@TableIndex(
  name: 'shifts_active_idx',
  columns: {#organizationId, #branchId, #status, #openedByUserId},
)
class Shifts extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get registerId =>
      text().references(Registers, #id, onDelete: KeyAction.restrict)();
  TextColumn get deviceId => text()();
  TextColumn get operationId => text()();
  TextColumn get closeOperationId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant<String>('open'))();
  IntColumn get openingCashMinor => integer().check(
    const CustomExpression<bool>('opening_cash_minor >= 0'),
  )();
  IntColumn get expectedCashMinor => integer().nullable()();
  IntColumn get countedCashMinor => integer().nullable().check(
    const CustomExpression<bool>(
      'counted_cash_minor IS NULL OR counted_cash_minor >= 0',
    ),
  )();
  IntColumn get discrepancyMinor => integer().nullable()();
  TextColumn get openingNotes => text().nullable()();
  TextColumn get closingNotes => text().nullable()();
  TextColumn get openedByUserId => text()();
  DateTimeColumn get openedAt => dateTime()();
  TextColumn get closedByUserId => text().nullable()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get approvedByUserId => text().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  TextColumn get approvalNotes => text().nullable()();
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
    {organizationId, closeOperationId},
    {id, organizationId, branchId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (register_id, organization_id, branch_id) '
        'REFERENCES registers (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    "CHECK (status IN ('open', 'closed'))",
    "CHECK ((status = 'open' AND closed_at IS NULL AND closed_by_user_id IS NULL) "
        "OR (status = 'closed' AND closed_at IS NOT NULL "
        'AND closed_by_user_id IS NOT NULL))',
  ];
}
