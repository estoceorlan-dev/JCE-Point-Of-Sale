import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';

@TableIndex(
  name: 'reason_codes_scope_idx',
  columns: {#organizationId, #branchScope, #category, #code},
  unique: true,
)
class ReasonCodes extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId => text().nullable().references(
    Branches,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get branchScope => text()();
  TextColumn get category => text()();
  TextColumn get code => text()();
  TextColumn get label => text()();
  BoolColumn get requiresNote =>
      boolean().withDefault(const Constant<bool>(false))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant<int>(0))();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {id, organizationId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    "CHECK ((branch_id IS NULL AND branch_scope = '*') OR "
        '(branch_id IS NOT NULL AND branch_scope = branch_id))',
  ];
}
