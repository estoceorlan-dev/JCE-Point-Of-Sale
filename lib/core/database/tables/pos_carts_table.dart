import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'customers_table.dart';
import 'organizations_table.dart';

@TableIndex(
  name: 'pos_carts_device_status_idx',
  columns: {#organizationId, #branchId, #deviceId, #status, #updatedAt},
)
class PosCarts extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.cascade)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.cascade)();
  TextColumn get deviceId => text()();
  TextColumn get status => text().check(
    const CustomExpression<bool>("status IN ('active', 'held')"),
  )();
  TextColumn get title => text().nullable()();
  TextColumn get customerId => text().nullable().references(
    Customers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get saleDiscountMinor => integer().withDefault(const Constant(0))();
  TextColumn get saleDiscountReason => text().nullable()();
  TextColumn get activeScope => text().nullable().unique()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PosCartItems extends Table {
  TextColumn get id => text()();
  TextColumn get cartId =>
      text().references(PosCarts, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text()();
  TextColumn get snapshotSku => text()();
  TextColumn get snapshotName => text()();
  IntColumn get quantityMilli =>
      integer().check(const CustomExpression<bool>('quantity_milli > 0'))();
  IntColumn get itemDiscountMinor => integer().withDefault(const Constant(0))();
  TextColumn get discountReason => text().nullable()();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {cartId, productId},
  ];
}
