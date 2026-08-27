import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';

@TableIndex(
  name: 'registers_branch_idx',
  columns: {#organizationId, #branchId, #isActive},
)
class Registers extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get assignedDeviceId => text().nullable()();
  TextColumn get assignedByUserId => text().nullable()();
  DateTimeColumn get assignedAt => dateTime().nullable()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(true))();
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
    {organizationId, branchId, code},
    {organizationId, branchId, assignedDeviceId},
    {id, organizationId, branchId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
  ];
}
