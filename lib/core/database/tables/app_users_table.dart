import 'package:drift/drift.dart';

import 'organizations_table.dart';

class AppUsers extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get firebaseUid => text().nullable()();
  TextColumn get email => text()();
  TextColumn get displayName => text()();
  TextColumn get status => text()();
  DateTimeColumn get invitedAt => dateTime().nullable()();
  DateTimeColumn get activatedAt => dateTime().nullable()();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, email},
  ];
}
