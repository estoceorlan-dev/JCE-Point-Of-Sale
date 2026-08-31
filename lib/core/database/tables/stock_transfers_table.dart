import 'package:drift/drift.dart';

import 'app_users_table.dart';
import 'organizations_table.dart';

@TableIndex(
  name: 'stock_transfers_source_status_idx',
  columns: {#organizationId, #sourceBranchId, #status, #updatedAt},
)
@TableIndex(
  name: 'stock_transfers_destination_status_idx',
  columns: {#organizationId, #destinationBranchId, #status, #updatedAt},
)
class StockTransfers extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get sourceBranchId => text()();
  TextColumn get destinationBranchId => text()();
  TextColumn get transferNumber => text()();
  TextColumn get status => text().check(
    const CustomExpression<bool>(
      "status IN ('draft', 'submitted', 'approved', 'rejected', "
      "'shipped', 'received', 'cancelled')",
    ),
  )();
  BoolColumn get approvalRequired =>
      boolean().withDefault(const Constant<bool>(false))();
  TextColumn get notes => text().nullable()();
  @ReferenceName('createdTransfers')
  TextColumn get createdByUserId =>
      text().references(AppUsers, #id, onDelete: KeyAction.restrict)();
  @ReferenceName('approvedTransfers')
  TextColumn get approvedByUserId => text().nullable().references(
    AppUsers,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get rejectionReason => text().nullable()();
  TextColumn get cancellationReason => text().nullable()();
  DateTimeColumn get submittedAt => dateTime().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  DateTimeColumn get shippedAt => dateTime().nullable()();
  DateTimeColumn get receivedAt => dateTime().nullable()();
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
    {organizationId, transferNumber},
    {id, organizationId},
  ];

  @override
  List<String> get customConstraints => const [
    'CHECK (source_branch_id <> destination_branch_id)',
  ];
}
