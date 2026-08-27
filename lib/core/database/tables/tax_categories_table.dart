import 'package:drift/drift.dart';

import 'organizations_table.dart';

class TaxCategories extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get code => text()();
  TextColumn get name => text()();
  IntColumn get rateBasisPoints => integer().check(
    const CustomExpression<bool>(
      'rate_basis_points >= 0 AND rate_basis_points <= 10000',
    ),
  )();
  BoolColumn get isInclusive =>
      boolean().withDefault(const Constant<bool>(true))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, code},
    {id, organizationId},
  ];
}
