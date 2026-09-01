import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../domain/entities/customer.dart';
import '../../domain/entities/loyalty_account.dart';

class CustomersLocalDataSource {
  const CustomersLocalDataSource(this.database);

  final db.AppDatabase database;

  Stream<List<CustomerSummary>> watchCustomers({
    required String organizationId,
    String search = '',
    bool includeInactive = false,
  }) {
    final query = database.select(database.customers)
      ..where((row) {
        var predicate = row.organizationId.equals(organizationId);
        if (!includeInactive) {
          predicate = predicate & row.status.equals('active');
        }
        final normalized = _normalizeSearch(search);
        if (normalized.isNotEmpty) {
          final phone = _normalizePhone(search);
          var matches =
              row.normalizedName.like('%$normalized%') |
              row.normalizedEmail.like('%${search.trim().toLowerCase()}%') |
              row.customerNumber.like('%${search.trim().toUpperCase()}%');
          if (phone.isNotEmpty) {
            matches = matches | row.normalizedPhone.like('%$phone%');
          }
          predicate = predicate & matches;
        }
        return predicate;
      })
      ..orderBy([
        (row) => OrderingTerm.asc(row.normalizedName),
        (row) => OrderingTerm.asc(row.customerNumber),
      ]);
    return query.watch().asyncMap((rows) => Future.wait(rows.map(_mapSummary)));
  }

  Stream<CustomerProfile?> watchCustomerProfile({
    required String organizationId,
    required String branchId,
    required String customerId,
  }) {
    return database
        .customSelect(
          'SELECT 1',
          readsFrom: {
            database.customers,
            database.customerAddresses,
            database.customerNotes,
            database.loyaltyAccounts,
            database.loyaltyLedgerEntries,
            database.sales,
          },
        )
        .watchSingle()
        .asyncMap(
          (_) => _loadProfile(
            organizationId: organizationId,
            branchId: branchId,
            customerId: customerId,
          ),
        );
  }

  Future<CustomerProfile?> _loadProfile({
    required String organizationId,
    required String branchId,
    required String customerId,
  }) async {
    final customer =
        await (database.select(database.customers)..where(
              (row) =>
                  row.id.equals(customerId) &
                  row.organizationId.equals(organizationId),
            ))
            .getSingleOrNull();
    if (customer == null) return null;
    final addresses =
        await (database.select(database.customerAddresses)
              ..where(
                (row) =>
                    row.customerId.equals(customerId) & row.deletedAt.isNull(),
              )
              ..orderBy([
                (row) => OrderingTerm.desc(row.isPrimary),
                (row) => OrderingTerm.asc(row.label),
              ]))
            .get();
    final notes =
        await (database.select(database.customerNotes)
              ..where(
                (row) =>
                    row.customerId.equals(customerId) &
                    row.branchId.equals(branchId) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
            .get();
    final sales =
        await (database.select(database.sales)
              ..where(
                (row) =>
                    row.customerId.equals(customerId) &
                    row.organizationId.equals(organizationId) &
                    row.branchId.equals(branchId) &
                    row.status.equals('draft').not(),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.completedAt)]))
            .get();
    final account =
        await (database.select(database.loyaltyAccounts)..where(
              (row) =>
                  row.customerId.equals(customerId) &
                  row.organizationId.equals(organizationId),
            ))
            .getSingleOrNull();
    return CustomerProfile(
      customer: await _mapSummary(customer),
      addresses: addresses
          .map(
            (row) => CustomerAddress(
              id: row.id,
              label: row.label,
              recipientName: row.recipientName,
              lineOne: row.lineOne,
              lineTwo: row.lineTwo,
              city: row.city,
              province: row.province,
              postalCode: row.postalCode,
              countryCode: row.countryCode,
              isPrimary: row.isPrimary,
              version: row.version,
            ),
          )
          .toList(growable: false),
      notes: notes
          .map(
            (row) => CustomerNote(
              id: row.id,
              body: row.body,
              createdByUserId: row.createdByUserId,
              createdAt: row.createdAt,
            ),
          )
          .toList(growable: false),
      purchases: sales
          .map(
            (row) => CustomerPurchase(
              saleId: row.id,
              receiptNumber: row.receiptNumber ?? 'Pending',
              status: row.status,
              totalMinor: row.totalMinor,
              completedAt: row.completedAt ?? row.createdAt,
            ),
          )
          .toList(growable: false),
      loyaltyAccount: account == null ? null : await _mapAccount(account),
    );
  }

  Future<CustomerSummary> _mapSummary(db.Customer row) async {
    final account = await (database.select(
      database.loyaltyAccounts,
    )..where((value) => value.customerId.equals(row.id))).getSingleOrNull();
    return CustomerSummary(
      id: row.id,
      customerNumber: row.customerNumber,
      displayName: row.displayName,
      email: row.email,
      phone: row.phone,
      birthDate: row.birthDate,
      marketingConsent: row.marketingConsent,
      status: CustomerStatus.fromDatabase(row.status),
      mergedIntoCustomerId: row.mergedIntoCustomerId,
      version: row.version,
      loyaltyPoints: account?.pointsBalance,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<LoyaltyAccount> _mapAccount(db.LoyaltyAccount row) async {
    final entries =
        await (database.select(database.loyaltyLedgerEntries)
              ..where((entry) => entry.accountId.equals(row.id))
              ..orderBy([(entry) => OrderingTerm.desc(entry.occurredAt)]))
            .get();
    return LoyaltyAccount(
      id: row.id,
      status: row.status,
      pointsBalance: row.pointsBalance,
      lifetimeEarnedPoints: row.lifetimeEarnedPoints,
      lifetimeRedeemedPoints: row.lifetimeRedeemedPoints,
      version: row.version,
      entries: entries
          .map(
            (entry) => LoyaltyLedgerEntry(
              id: entry.id,
              operationId: entry.operationId,
              type: LoyaltyEntryType.fromDatabase(entry.entryType),
              pointsDelta: entry.pointsDelta,
              balanceAfter: entry.balanceAfter,
              reason: entry.reason,
              createdByUserId: entry.createdByUserId,
              occurredAt: entry.occurredAt,
              saleId: entry.saleId,
            ),
          )
          .toList(growable: false),
    );
  }
}

String _normalizeSearch(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

String _normalizePhone(String value) => value.replaceAll(RegExp('[^0-9]'), '');
