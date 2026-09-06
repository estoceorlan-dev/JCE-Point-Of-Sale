import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'registers_table.dart';
import 'sales_table.dart';

@TableIndex(
  name: 'receipt_print_jobs_due_idx',
  columns: {#status, #nextAttemptAt, #createdAt},
)
@TableIndex(
  name: 'receipt_print_jobs_register_idx',
  columns: {#organizationId, #branchId, #registerId, #createdAt},
)
class ReceiptPrintJobs extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get registerId =>
      text().references(Registers, #id, onDelete: KeyAction.restrict)();
  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.restrict)();
  TextColumn get deduplicationKey => text().unique()();
  TextColumn get copyType => text().check(
    const CustomExpression<bool>("copy_type IN ('original', 'reprint')"),
  )();
  TextColumn get documentText => text()();
  TextColumn get status => text()
      .withDefault(const Constant<String>('pending'))
      .check(
        const CustomExpression<bool>(
          "status IN ('pending', 'processing', 'succeeded', "
          "'retryable_failure', 'permanent_failure')",
        ),
      )();
  IntColumn get attemptCount => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('attempt_count >= 0'))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get requestedByUserId => text()();
  DateTimeColumn get printedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (register_id, organization_id, branch_id) '
        'REFERENCES registers (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
  ];
}
