import 'package:drift/drift.dart';

import 'organizations_table.dart';
import 'products_table.dart';
import 'purchase_orders_table.dart';

class PurchaseOrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId => text()();
  TextColumn get purchaseOrderId =>
      text().references(PurchaseOrders, #id, onDelete: KeyAction.restrict)();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  IntColumn get orderedQuantityMilli => integer().check(
    const CustomExpression<bool>('ordered_quantity_milli > 0'),
  )();
  IntColumn get receivedQuantityMilli => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('received_quantity_milli >= 0'))();
  IntColumn get cancelledQuantityMilli => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('cancelled_quantity_milli >= 0'))();
  IntColumn get unitCostMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('unit_cost_minor >= 0'))();
  IntColumn get estimatedLandedCostMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(
        const CustomExpression<bool>('estimated_landed_cost_minor >= 0'),
      )();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {purchaseOrderId, productId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (purchase_order_id, organization_id, branch_id) '
        'REFERENCES purchase_orders (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) '
        'REFERENCES products (id, organization_id) ON DELETE RESTRICT',
    'CHECK (received_quantity_milli + cancelled_quantity_milli '
        '<= ordered_quantity_milli)',
  ];
}
