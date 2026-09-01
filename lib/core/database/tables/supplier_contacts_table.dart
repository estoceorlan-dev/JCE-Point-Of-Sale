import 'package:drift/drift.dart';

import 'organizations_table.dart';
import 'suppliers_table.dart';

class SupplierContacts extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get supplierId =>
      text().references(Suppliers, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text()();
  TextColumn get role => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isPrimary =>
      boolean().withDefault(const Constant<bool>(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (supplier_id, organization_id) '
        'REFERENCES suppliers (id, organization_id) ON DELETE RESTRICT',
    'CHECK (email IS NOT NULL OR phone IS NOT NULL)',
  ];
}
