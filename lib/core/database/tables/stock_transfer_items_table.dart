import 'package:drift/drift.dart';

import 'organizations_table.dart';
import 'products_table.dart';
import 'stock_transfers_table.dart';

class StockTransferItems extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get transferId =>
      text().references(StockTransfers, #id, onDelete: KeyAction.restrict)();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  TextColumn get sourceStockLocationId => text()();
  TextColumn get destinationStockLocationId => text()();
  TextColumn get damagedStockLocationId => text().nullable()();
  IntColumn get requestedQuantityMilli => integer().check(
    const CustomExpression<bool>('requested_quantity_milli > 0'),
  )();
  IntColumn get shippedQuantityMilli => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('shipped_quantity_milli >= 0'))();
  IntColumn get receivedQuantityMilli => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('received_quantity_milli >= 0'))();
  IntColumn get damagedQuantityMilli => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('damaged_quantity_milli >= 0'))();
  IntColumn get discrepancyQuantityMilli => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('discrepancy_quantity_milli >= 0'))();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {transferId, sourceStockLocationId, productId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (transfer_id, organization_id) '
        'REFERENCES stock_transfers (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) '
        'REFERENCES products (id, organization_id) ON DELETE RESTRICT',
    'CHECK (received_quantity_milli + damaged_quantity_milli '
        '<= shipped_quantity_milli)',
    'CHECK ((damaged_quantity_milli = 0) OR '
        '(damaged_stock_location_id IS NOT NULL))',
  ];
}
