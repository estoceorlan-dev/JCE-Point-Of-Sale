import 'package:drift/drift.dart';

import 'branches_table.dart';
import 'organizations_table.dart';
import 'register_claims_table.dart';
import 'sales_table.dart';

@TableIndex(
  name: 'sale_receipt_aliases_lookup_idx',
  columns: {#organizationId, #branchId, #aliasReceiptNumber},
)
class SaleReceiptAliases extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId =>
      text().references(Organizations, #id, onDelete: KeyAction.restrict)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.restrict)();
  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.cascade)();
  TextColumn get registerClaimId => text().nullable().references(
    RegisterClaims,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get aliasReceiptNumber => text()();
  TextColumn get canonicalReceiptNumber => text()();
  TextColumn get aliasKind =>
      text().withDefault(const Constant<String>('offline_printed'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {organizationId, branchId, aliasReceiptNumber},
    {saleId, aliasReceiptNumber},
  ];
}
