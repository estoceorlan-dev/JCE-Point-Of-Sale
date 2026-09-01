import 'package:drift/drift.dart';

import 'organizations_table.dart';

@TableIndex(
  name: 'suppliers_search_idx',
  columns: {#organizationId, #normalizedName, #isActive},
)
class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get code => text()();
  TextColumn get normalizedCode => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text()();
  TextColumn get taxIdentifier => text().nullable()();
  IntColumn get paymentTermsDays => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('payment_terms_days >= 0'))();
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
    {organizationId, normalizedCode},
    {id, organizationId},
  ];
}
