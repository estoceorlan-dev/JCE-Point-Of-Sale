import 'package:drift/drift.dart';

import 'organizations_table.dart';

class Roles extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
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
    {organizationId, code},
  ];
}
