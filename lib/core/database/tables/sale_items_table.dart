import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'products_table.dart';
import 'sales_table.dart';
import 'stock_locations_table.dart';

class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.restrict)();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  TextColumn get stockLocationId =>
      text().references(StockLocations, #id, onDelete: KeyAction.restrict)();
  IntColumn get lineNumber =>
      integer().check(const CustomExpression<bool>('line_number > 0'))();
  TextColumn get productNameSnapshot => text()();
  TextColumn get skuSnapshot => text()();
  TextColumn get barcodeSnapshot => text().nullable()();
  TextColumn get unitNameSnapshot => text()();
  IntColumn get quantityMilli =>
      integer().check(const CustomExpression<bool>('quantity_milli > 0'))();
  IntColumn get unitPriceMinorSnapshot => integer().check(
    const CustomExpression<bool>('unit_price_minor_snapshot >= 0'),
  )();
  IntColumn get unitCostMinorSnapshot => integer().check(
    const CustomExpression<bool>('unit_cost_minor_snapshot >= 0'),
  )();
  IntColumn get taxRateBasisPointsSnapshot => integer().check(
    const CustomExpression<bool>(
      'tax_rate_basis_points_snapshot >= 0 AND '
      'tax_rate_basis_points_snapshot <= 10000',
    ),
  )();
  BoolColumn get taxInclusiveSnapshot => boolean()();
  IntColumn get grossAmountMinor => integer().check(
    const CustomExpression<bool>('gross_amount_minor >= 0'),
  )();
  IntColumn get discountAmountMinor => integer().check(
    const CustomExpression<bool>('discount_amount_minor >= 0'),
  )();
  IntColumn get netAmountMinor =>
      integer().check(const CustomExpression<bool>('net_amount_minor >= 0'))();
  IntColumn get taxAmountMinor =>
      integer().check(const CustomExpression<bool>('tax_amount_minor >= 0'))();
  IntColumn get totalAmountMinor => integer().check(
    const CustomExpression<bool>('total_amount_minor >= 0'),
  )();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {saleId, lineNumber},
    {id, saleId},
    {id, organizationId, branchId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_id, organization_id, branch_id) '
        'REFERENCES sales (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) '
        'REFERENCES products (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (stock_location_id, organization_id, branch_id) '
        'REFERENCES stock_locations (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'CHECK (discount_amount_minor <= gross_amount_minor)',
  ];
}
