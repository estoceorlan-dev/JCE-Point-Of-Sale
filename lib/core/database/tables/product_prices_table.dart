import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'products_table.dart';

@TableIndex(
  name: 'product_prices_lookup_idx',
  columns: {#productId, #branchId, #effectiveFrom},
)
class ProductPrices extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get branchId => text().nullable().references(
    Branches,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get branchScope => text()();
  IntColumn get unitPriceMinor =>
      integer().check(const CustomExpression<bool>('unit_price_minor >= 0'))();
  DateTimeColumn get effectiveFrom => dateTime()();
  DateTimeColumn get effectiveTo => dateTime().nullable()();
  TextColumn get createdByUserId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {productId, branchId, effectiveFrom},
    {productId, branchScope, effectiveFrom},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (product_id, organization_id) '
        'REFERENCES products (id, organization_id) ON DELETE CASCADE',
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    "CHECK ((branch_id IS NULL AND branch_scope = '*') OR "
        '(branch_id IS NOT NULL AND branch_scope = branch_id))',
  ];
}
