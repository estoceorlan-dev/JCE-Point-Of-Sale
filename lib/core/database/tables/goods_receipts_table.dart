import 'package:drift/drift.dart';

import 'app_users_table.dart';
import 'branches_table.dart';
import 'organizations_table.dart';
import 'purchase_orders_table.dart';
import 'stock_locations_table.dart';
import 'suppliers_table.dart';

@TableIndex(
  name: 'goods_receipts_history_idx',
  columns: {#organizationId, #branchId, #receivedAt},
)
class GoodsReceipts extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get purchaseOrderId =>
      text().references(PurchaseOrders, #id, onDelete: KeyAction.restrict)();
  TextColumn get supplierId =>
      text().references(Suppliers, #id, onDelete: KeyAction.restrict)();
  TextColumn get stockLocationId =>
      text().references(StockLocations, #id, onDelete: KeyAction.restrict)();
  TextColumn get receiptNumber => text()();
  TextColumn get operationId => text().unique()();
  TextColumn get supplierDocumentNumber => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get receivedByUserId =>
      text().references(AppUsers, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get receivedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, branchId, receiptNumber},
    {id, organizationId, branchId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (purchase_order_id, organization_id, branch_id) '
        'REFERENCES purchase_orders (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
    'FOREIGN KEY (supplier_id, organization_id) '
        'REFERENCES suppliers (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (stock_location_id, organization_id, branch_id) '
        'REFERENCES stock_locations (id, organization_id, branch_id) '
        'ON DELETE RESTRICT',
  ];
}
