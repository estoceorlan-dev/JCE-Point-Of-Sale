import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';

@TableIndex(
  name: 'feature_flags_scope_idx',
  columns: {#organizationId, #branchScope, #flagKey},
  unique: true,
)
class FeatureFlags extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId => text().nullable().references(
    Branches,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get branchScope => text()();
  TextColumn get flagKey => text()();
  BoolColumn get isEnabled =>
      boolean().withDefault(const Constant<bool>(false))();
  TextColumn get configurationJson =>
      text().withDefault(const Constant<String>('{}'))();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

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
