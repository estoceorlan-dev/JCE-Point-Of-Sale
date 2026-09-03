import 'package:drift/drift.dart';

import 'organizations_table.dart';

@TableIndex(
  name: 'organization_settings_key_idx',
  columns: {#organizationId, #settingKey},
  unique: true,
)
class OrganizationSettings extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get settingKey => text()();
  TextColumn get valueJson => text()();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  TextColumn get updatedByUserId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {id, organizationId},
  ];
}
