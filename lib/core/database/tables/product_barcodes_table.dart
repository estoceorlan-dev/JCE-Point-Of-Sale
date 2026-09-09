import 'package:drift/drift.dart';

import 'organizations_table.dart';
import 'products_table.dart';

@TableIndex(
  name: 'product_barcodes_search_idx',
  columns: {#organizationId, #normalizedBarcode},
)
@TableIndex(
  name: 'product_barcodes_product_lookup_idx',
  columns: {#productId, #deletedAt, #normalizedBarcode},
)
class ProductBarcodes extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get barcode => text()();
  TextColumn get normalizedBarcode => text()();
  BoolColumn get isPrimary =>
      boolean().withDefault(const Constant<bool>(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, barcode},
    {organizationId, normalizedBarcode},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (product_id, organization_id) '
        'REFERENCES products (id, organization_id) ON DELETE CASCADE',
  ];
}
