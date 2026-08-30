import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';

@TableIndex(
  name: 'approval_requests_status_idx',
  columns: {#organizationId, #branchId, #status, #requestedAt},
)
class ApprovalRequests extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get operationId => text()();
  TextColumn get requestType => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get status =>
      text().withDefault(const Constant<String>('pending'))();
  TextColumn get requestedByUserId => text()();
  TextColumn get reason => text()();
  IntColumn get thresholdMinor => integer().nullable().check(
    const CustomExpression<bool>(
      'threshold_minor IS NULL OR threshold_minor >= 0',
    ),
  )();
  IntColumn get actualAmountMinor => integer().check(
    const CustomExpression<bool>('actual_amount_minor >= 0'),
  )();
  DateTimeColumn get requestedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

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
    "CHECK (request_type IN ('sale_return', 'sale_void'))",
    "CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'))",
    "CHECK ((status = 'pending' AND resolved_at IS NULL) OR "
        "(status <> 'pending' AND resolved_at IS NOT NULL))",
  ];
}
