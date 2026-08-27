import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'registers_table.dart';

class ReceiptSequences extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get registerId =>
      text().references(Registers, #id, onDelete: KeyAction.restrict)();
  IntColumn get nextSequence => integer()
      .withDefault(const Constant<int>(1))
      .check(const CustomExpression<bool>('next_sequence > 0'))();
  DateTimeColumn get lastIssuedAt => dateTime().nullable()();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, branchId, registerId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (register_id, organization_id, branch_id) '
        'REFERENCES registers (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
  ];
}
