import 'package:drift/drift.dart';

import 'customers_table.dart';
import 'organizations_table.dart';

class CustomerAddresses extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.restrict)();
  TextColumn get label => text()();
  TextColumn get recipientName => text().nullable()();
  TextColumn get lineOne => text()();
  TextColumn get lineTwo => text().nullable()();
  TextColumn get city => text()();
  TextColumn get province => text().nullable()();
  TextColumn get postalCode => text().nullable()();
  TextColumn get countryCode =>
      text().withDefault(const Constant<String>('PH'))();
  BoolColumn get isPrimary =>
      boolean().withDefault(const Constant<bool>(false))();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (customer_id, organization_id) '
        'REFERENCES customers (id, organization_id) ON DELETE RESTRICT',
  ];
}
