import 'package:drift/drift.dart';

import 'app_users_table.dart';
import 'branches_table.dart';
import 'organizations_table.dart';
import 'suppliers_table.dart';

@TableIndex(
  name: 'purchase_orders_branch_status_idx',
  columns: {#organizationId, #branchId, #status, #updatedAt},
)
class PurchaseOrders extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get supplierId =>
      text().references(Suppliers, #id, onDelete: KeyAction.restrict)();
  TextColumn get orderNumber => text()();
  TextColumn get status => text().check(
    const CustomExpression<bool>(
      "status IN ('draft', 'submitted', 'approved', 'partially_received', "
      "'received', 'cancelled')",
    ),
  )();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get expectedDeliveryAt => dateTime().nullable()();
  TextColumn get createdByUserId =>
      text().references(AppUsers, #id, onDelete: KeyAction.restrict)();
  @ReferenceName('approvedPurchaseOrders')
  TextColumn get approvedByUserId => text().nullable().references(
    AppUsers,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get cancellationReason => text().nullable()();
  DateTimeColumn get submittedAt => dateTime().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, branchId, orderNumber},
    {id, organizationId, branchId},
  ];

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) '
        'REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (supplier_id, organization_id) '
        'REFERENCES suppliers (id, organization_id) ON DELETE RESTRICT',
  ];
}
