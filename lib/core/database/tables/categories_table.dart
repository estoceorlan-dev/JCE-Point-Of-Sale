import 'package:drift/drift.dart';

import 'organizations_table.dart';

@TableIndex(
  name: 'categories_search_idx',
  columns: {#organizationId, #normalizedName},
)
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text()();
  TextColumn get normalizedName => text()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, normalizedName},
    {id, organizationId},
  ];
}
