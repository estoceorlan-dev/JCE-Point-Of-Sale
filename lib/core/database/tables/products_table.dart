import 'package:drift/drift.dart';

import 'categories_table.dart';
import 'organizations_table.dart';
import 'tax_categories_table.dart';
import 'units_table.dart';

@TableIndex(
  name: 'products_name_search_idx',
  columns: {#organizationId, #normalizedName},
)
@TableIndex(
  name: 'products_sku_search_idx',
  columns: {#organizationId, #normalizedSku},
)
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get unitId =>
      text().references(Units, #id, onDelete: KeyAction.restrict)();
  TextColumn get taxCategoryId => text().nullable().references(
    TaxCategories,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get sku => text()();
  TextColumn get normalizedSku => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, sku},
    {organizationId, normalizedSku},
    {id, organizationId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (category_id, organization_id) '
        'REFERENCES categories (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (unit_id, organization_id) '
        'REFERENCES units (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (tax_category_id, organization_id) '
        'REFERENCES tax_categories (id, organization_id) ON DELETE RESTRICT',
  ];
}
