import 'package:drift/drift.dart';

import 'goods_receipts_table.dart';
import 'inventory_transactions_table.dart';
import 'organizations_table.dart';
import 'products_table.dart';
import 'purchase_order_items_table.dart';

class GoodsReceiptItems extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId => text()();
  TextColumn get goodsReceiptId =>
      text().references(GoodsReceipts, #id, onDelete: KeyAction.restrict)();
  TextColumn get purchaseOrderItemId => text().references(
    PurchaseOrderItems,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  TextColumn get inventoryTransactionId => text().references(
    InventoryTransactions,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get receivedQuantityMilli => integer().check(
    const CustomExpression<bool>('received_quantity_milli > 0'),
  )();
  IntColumn get unitCostMinor =>
      integer().check(const CustomExpression<bool>('unit_cost_minor >= 0'))();
  IntColumn get freightCostMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('freight_cost_minor >= 0'))();
  IntColumn get dutyCostMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('duty_cost_minor >= 0'))();
  IntColumn get otherLandedCostMinor => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('other_landed_cost_minor >= 0'))();
  IntColumn get landedUnitCostMinor => integer().check(
    const CustomExpression<bool>('landed_unit_cost_minor >= 0'),
  )();
  IntColumn get weightedAverageCostMinorAfter => integer().check(
    const CustomExpression<bool>('weighted_average_cost_minor_after >= 0'),
  )();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {goodsReceiptId, purchaseOrderItemId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (goods_receipt_id, organization_id, branch_id) '
        'REFERENCES goods_receipts (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) '
        'REFERENCES products (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (inventory_transaction_id, organization_id, branch_id) '
        'REFERENCES inventory_transactions (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
  ];
}
