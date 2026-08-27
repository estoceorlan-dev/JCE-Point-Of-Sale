import 'package:drift/drift.dart';

import 'organizations_table.dart';
import 'products_table.dart';
import 'stock_counts_table.dart';

class StockCountItems extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get stockCountId =>
      text().references(StockCounts, #id, onDelete: KeyAction.restrict)();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  IntColumn get expectedQuantityMilli => integer()();
  IntColumn get countedQuantityMilli => integer().nullable()();
  IntColumn get varianceQuantityMilli => integer().nullable()();
  TextColumn get countedByUserId => text().nullable()();
  DateTimeColumn get countedAt => dateTime().nullable()();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {stockCountId, productId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (stock_count_id, organization_id) '
        'REFERENCES stock_counts (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) '
        'REFERENCES products (id, organization_id) ON DELETE RESTRICT',
  ];
}
