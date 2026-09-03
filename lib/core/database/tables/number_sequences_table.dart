import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';

@TableIndex(
  name: 'number_sequences_scope_idx',
  columns: {#organizationId, #branchScope, #sequenceKey},
  unique: true,
)
class NumberSequences extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId => text().nullable().references(
    Branches,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get branchScope => text()();
  TextColumn get sequenceKey => text()();
  TextColumn get prefix => text().withDefault(const Constant<String>(''))();
  IntColumn get nextValue => integer()
      .withDefault(const Constant<int>(1))
      .check(const CustomExpression<bool>('next_value >= 1'))();
  IntColumn get padding => integer()
      .withDefault(const Constant<int>(6))
      .check(const CustomExpression<bool>('padding >= 1 AND padding <= 12'))();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    "CHECK ((branch_id IS NULL AND branch_scope = '*') OR "
        '(branch_id IS NOT NULL AND branch_scope = branch_id))',
  ];
}
