import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'products_table.dart';
import 'sale_items_table.dart';
import 'sale_returns_table.dart';
import 'stock_locations_table.dart';

class SaleReturnItems extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get saleReturnId =>
      text().references(SaleReturns, #id, onDelete: KeyAction.restrict)();
  TextColumn get saleItemId =>
      text().references(SaleItems, #id, onDelete: KeyAction.restrict)();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  TextColumn get disposition => text()();
  TextColumn get destinationStockLocationId => text().nullable().references(
    StockLocations,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get quantityMilli =>
      integer().check(const CustomExpression<bool>('quantity_milli > 0'))();
  IntColumn get subtotalMinor =>
      integer().check(const CustomExpression<bool>('subtotal_minor >= 0'))();
  IntColumn get discountMinor =>
      integer().check(const CustomExpression<bool>('discount_minor >= 0'))();
  IntColumn get taxMinor =>
      integer().check(const CustomExpression<bool>('tax_minor >= 0'))();
  IntColumn get totalMinor =>
      integer().check(const CustomExpression<bool>('total_minor >= 0'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {saleReturnId, saleItemId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_return_id, organization_id, branch_id) '
        'REFERENCES sale_returns (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) '
        'REFERENCES products (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (destination_stock_location_id, organization_id, branch_id) '
        'REFERENCES stock_locations (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    "CHECK (disposition IN ('restock', 'damaged', 'non_restock'))",
    'CHECK ((disposition = \'non_restock\' AND '
        'destination_stock_location_id IS NULL) OR '
        '(disposition <> \'non_restock\' AND '
        'destination_stock_location_id IS NOT NULL))',
    'CHECK (discount_minor <= subtotal_minor)',
  ];
}
