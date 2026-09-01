import 'package:drift/drift.dart';

import 'organizations_table.dart';

@TableIndex(
  name: 'customers_name_search_idx',
  columns: {#organizationId, #normalizedName, #status},
)
@TableIndex(
  name: 'customers_email_search_idx',
  columns: {#organizationId, #normalizedEmail},
)
@TableIndex(
  name: 'customers_phone_search_idx',
  columns: {#organizationId, #normalizedPhone},
)
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get customerNumber => text()();
  TextColumn get displayName => text()();
  TextColumn get normalizedName => text()();
  TextColumn get email => text().nullable()();
  TextColumn get normalizedEmail => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get normalizedPhone => text().nullable()();
  DateTimeColumn get birthDate => dateTime().nullable()();
  BoolColumn get marketingConsent =>
      boolean().withDefault(const Constant<bool>(false))();
  TextColumn get status =>
      text().withDefault(const Constant<String>('active'))();
  TextColumn get mergedIntoCustomerId => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get anonymizedAt => dateTime().nullable()();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, customerNumber},
    {id, organizationId},
  ];

  @override
  List<String> get customConstraints => const [
    "CHECK (status IN ('active', 'archived', 'anonymized', 'merged'))",
    "CHECK ((status = 'merged' AND merged_into_customer_id IS NOT NULL) OR "
        "(status <> 'merged' AND merged_into_customer_id IS NULL))",
    'FOREIGN KEY (merged_into_customer_id, organization_id) '
        'REFERENCES customers (id, organization_id) ON DELETE RESTRICT',
  ];
}
