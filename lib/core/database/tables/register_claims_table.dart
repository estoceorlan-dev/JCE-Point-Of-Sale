import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'registers_table.dart';

@TableIndex(
  name: 'register_claims_unresolved_idx',
  columns: {#organizationId, #branchId, #status, #createdAt},
)
@TableIndex(
  name: 'register_claims_device_idx',
  columns: {#organizationId, #deviceId, #status},
)
@DataClassName('RegisterClaimRecord')
class RegisterClaims extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get requestedRegisterId =>
      text().references(Registers, #id, onDelete: KeyAction.restrict)();
  TextColumn get resolvedRegisterId => text().nullable().references(
    Registers,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get deviceId => text()();
  TextColumn get claimedByUserId => text()();
  TextColumn get status => text().check(
    const CustomExpression<bool>(
      "status IN ('provisional', 'accepted', 'rejected', 'resolved', 'released')",
    ),
  )();
  TextColumn get rejectionCode => text().nullable()();
  TextColumn get rejectionMessage => text().nullable()();
  TextColumn get resolutionOperationId => text().nullable()();
  TextColumn get resolvedByUserId => text().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get releasedByUserId => text().nullable()();
  DateTimeColumn get releasedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
