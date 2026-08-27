import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'sale_items_table.dart';
import 'sales_table.dart';

class SaleDiscounts extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.restrict)();
  TextColumn get saleItemId => text().nullable().references(
    SaleItems,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get discountScope => text()();
  TextColumn get discountType =>
      text().withDefault(const Constant<String>('fixed_amount'))();
  IntColumn get amountMinor =>
      integer().check(const CustomExpression<bool>('amount_minor > 0'))();
  TextColumn get reason => text()();
  TextColumn get approvedByUserId => text().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_id, organization_id, branch_id) '
        'REFERENCES sales (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_item_id, sale_id) '
        'REFERENCES sale_items (id, sale_id) ON DELETE RESTRICT',
    "CHECK (discount_scope IN ('item', 'sale'))",
    "CHECK (discount_type = 'fixed_amount')",
    "CHECK ((discount_scope = 'item' AND sale_item_id IS NOT NULL) OR "
        "(discount_scope = 'sale' AND sale_item_id IS NULL))",
  ];
}
