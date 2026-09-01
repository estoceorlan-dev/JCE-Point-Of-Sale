import 'package:drift/drift.dart';

import 'organizations_table.dart';
import 'products_table.dart';
import 'suppliers_table.dart';

class SupplierProducts extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get supplierId =>
      text().references(Suppliers, #id, onDelete: KeyAction.restrict)();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  TextColumn get supplierSku => text().nullable()();
  IntColumn get defaultUnitCostMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('default_unit_cost_minor >= 0'))();
  IntColumn get minimumOrderQuantityMilli => integer()
      .withDefault(const Constant<int>(1000))
      .check(
        const CustomExpression<bool>('minimum_order_quantity_milli > 0'),
      )();
  IntColumn get leadTimeDays => integer().nullable().check(
    const CustomExpression<bool>(
      'lead_time_days IS NULL OR lead_time_days >= 0',
    ),
  )();
  BoolColumn get isPreferred =>
      boolean().withDefault(const Constant<bool>(false))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant<bool>(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {supplierId, productId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (supplier_id, organization_id) '
        'REFERENCES suppliers (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) '
        'REFERENCES products (id, organization_id) ON DELETE RESTRICT',
  ];
}
