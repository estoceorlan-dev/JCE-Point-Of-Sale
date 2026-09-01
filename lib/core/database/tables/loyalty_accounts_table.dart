import 'package:drift/drift.dart';

import 'customers_table.dart';
import 'organizations_table.dart';

class LoyaltyAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.restrict)();
  TextColumn get status =>
      text().withDefault(const Constant<String>('active'))();
  IntColumn get pointsBalance => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('points_balance >= 0'))();
  IntColumn get lifetimeEarnedPoints => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('lifetime_earned_points >= 0'))();
  IntColumn get lifetimeRedeemedPoints => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('lifetime_redeemed_points >= 0'))();
  IntColumn get version => integer()
      .withDefault(const Constant<int>(0))
      .check(const CustomExpression<bool>('version >= 0'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, customerId},
    {id, organizationId},
  ];

  @override
  List<String> get customConstraints => const [
    "CHECK (status IN ('active', 'disabled', 'closed', 'merged'))",
    'FOREIGN KEY (customer_id, organization_id) '
        'REFERENCES customers (id, organization_id) ON DELETE RESTRICT',
  ];
}
