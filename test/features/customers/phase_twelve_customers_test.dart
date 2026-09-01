import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart' hide Customer;
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/customers/data/data_sources/customers_local_data_source.dart';
import 'package:jce_pos/features/customers/data/repositories/drift_customers_repository.dart';
import 'package:jce_pos/features/customers/domain/entities/customer.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  group('Phase 12 customer management and loyalty', () {
    late AppDatabase database;
    late DriftCustomersRepository repository;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      await _seed(database);
      repository = _repository(database);
    });

    tearDown(() => database.close());

    test(
      'offline customer creation is idempotent and enters the outbox',
      () async {
        const draft = CustomerDraft(
          displayName: 'Ana Reyes',
          email: ' ANA@EXAMPLE.COM ',
          phone: '+63 917 555 0101',
          operationId: 'create-customer',
        );

        final first = await repository.createCustomer(
          context: _context,
          draft: draft,
        );
        final retry = await repository.createCustomer(
          context: _context,
          draft: draft,
        );

        expect(first.isSuccess, isTrue, reason: first.failureOrNull?.message);
        expect(retry.valueOrNull, first.valueOrNull);
        final customer = await database.select(database.customers).getSingle();
        expect(customer.normalizedEmail, 'ana@example.com');
        expect(customer.normalizedPhone, '639175550101');
        final commands = await database
            .select(database.syncOutboxEntries)
            .get();
        expect(commands, hasLength(1));
        expect(commands.single.commandType, 'customer.create');
      },
    );

    test(
      'duplicate contact is rejected unless explicitly acknowledged',
      () async {
        await _create(
          repository,
          name: 'Ana Reyes',
          email: 'ana@example.com',
          operationId: 'ana',
        );

        final rejected = await repository.createCustomer(
          context: _context,
          draft: const CustomerDraft(
            displayName: 'Ana R.',
            email: 'ANA@example.com',
            operationId: 'duplicate-rejected',
          ),
        );
        final allowed = await repository.createCustomer(
          context: _context,
          draft: const CustomerDraft(
            displayName: 'Ana Separate',
            email: 'ANA@example.com',
            allowDuplicateContact: true,
            operationId: 'duplicate-allowed',
          ),
        );

        expect(rejected.failureOrNull, isA<ConflictFailure>());
        expect(
          allowed.isSuccess,
          isTrue,
          reason: allowed.failureOrNull?.message,
        );
        expect(await database.select(database.customers).get(), hasLength(2));
      },
    );

    test('loyalty retries never duplicate points or ledger entries', () async {
      final customer = await _create(
        repository,
        name: 'Loyal Customer',
        email: 'loyal@example.com',
        operationId: 'loyal-customer',
        enableLoyalty: true,
      );

      final first = await repository.adjustLoyaltyPoints(
        context: _context,
        customerId: customer.id,
        pointsDelta: 25,
        reason: 'Service recovery credit',
        operationId: 'loyalty-adjustment',
      );
      final retry = await repository.adjustLoyaltyPoints(
        context: _context,
        customerId: customer.id,
        pointsDelta: 25,
        reason: 'Service recovery credit',
        operationId: 'loyalty-adjustment',
      );

      expect(
        first.isSuccess,
        isTrue,
        reason:
            '${first.failureOrNull?.message}: ${first.failureOrNull?.cause}',
      );
      expect(retry.isSuccess, isTrue);
      expect(
        (await database.select(database.loyaltyAccounts).getSingle())
            .pointsBalance,
        25,
      );
      expect(
        await database.select(database.loyaltyLedgerEntries).get(),
        hasLength(1),
      );
    });

    test(
      'merge preserves purchases and transfers points with ledger entries',
      () async {
        final source = await _create(
          repository,
          name: 'Duplicate Customer',
          email: 'source@example.com',
          operationId: 'source',
          enableLoyalty: true,
        );
        final target = await _create(
          repository,
          name: 'Canonical Customer',
          email: 'target@example.com',
          operationId: 'target',
          enableLoyalty: true,
        );
        await repository.adjustLoyaltyPoints(
          context: _context,
          customerId: source.id,
          pointsDelta: 40,
          reason: 'Source balance',
          operationId: 'source-points',
        );
        await repository.adjustLoyaltyPoints(
          context: _context,
          customerId: target.id,
          pointsDelta: 10,
          reason: 'Target balance',
          operationId: 'target-points',
        );
        await _insertSale(database, id: 'customer-sale', customerId: source.id);

        final result = await repository.mergeCustomers(
          context: _context,
          source: await _refresh(repository, source.id),
          target: await _refresh(repository, target.id),
          operationId: 'merge-customers',
        );

        expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
        final sourceRow = await (database.select(
          database.customers,
        )..where((row) => row.id.equals(source.id))).getSingle();
        expect(sourceRow.status, 'merged');
        expect(sourceRow.mergedIntoCustomerId, target.id);
        expect(
          (await database.select(database.sales).getSingle()).customerId,
          target.id,
        );
        final accounts = await database.select(database.loyaltyAccounts).get();
        expect(
          accounts
              .singleWhere((account) => account.customerId == target.id)
              .pointsBalance,
          50,
        );
        expect(
          (await database.select(database.loyaltyLedgerEntries).get()).where(
            (entry) => entry.entryType.startsWith('merge_'),
          ),
          hasLength(2),
        );
      },
    );

    test('anonymization scrubs PII but keeps the sale attribution', () async {
      final customer = await _create(
        repository,
        name: 'Privacy Customer',
        email: 'private@example.com',
        operationId: 'privacy-customer',
      );
      final note = await repository.addNote(
        context: _context,
        customerId: customer.id,
        body: 'Sensitive delivery preference',
        operationId: 'privacy-note',
      );
      expect(
        note.isSuccess,
        isTrue,
        reason: '${note.failureOrNull?.message}: ${note.failureOrNull?.cause}',
      );
      await _insertSale(database, id: 'privacy-sale', customerId: customer.id);

      final result = await repository.anonymizeCustomer(
        context: _context,
        customer: await _refresh(repository, customer.id),
        reason: 'Verified data subject erasure request',
        operationId: 'privacy-anonymize',
      );

      expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
      final row = await database.select(database.customers).getSingle();
      expect(row.status, 'anonymized');
      expect(row.email, isNull);
      expect(row.phone, isNull);
      expect(row.marketingConsent, isFalse);
      expect(
        (await database.select(database.sales).getSingle()).customerId,
        row.id,
      );
      expect(
        (await database.select(database.customerNotes).getSingle()).body,
        '[anonymized]',
      );
    });

    test(
      'purchase history is branch-scoped and sales allow no customer',
      () async {
        final customer = await _create(
          repository,
          name: 'History Customer',
          operationId: 'history-customer',
        );
        await _insertSale(
          database,
          id: 'attributed-sale',
          customerId: customer.id,
        );
        await _insertSale(database, id: 'walk-in-sale');

        final profile = await repository
            .watchCustomerProfile(context: _context, customerId: customer.id)
            .first;

        expect(profile?.purchases.map((purchase) => purchase.saleId), [
          'attributed-sale',
        ]);
        expect(
          (await database.select(database.sales).get())
              .singleWhere((sale) => sale.id == 'walk-in-sale')
              .customerId,
          isNull,
        );
      },
    );
  });
}

const _context = BusinessContext(
  organizationId: 'organization',
  branchId: 'branch',
  actorUserId: 'user',
);

DriftCustomersRepository _repository(AppDatabase database) {
  return DriftCustomersRepository(
    database: database,
    localDataSource: CustomersLocalDataSource(database),
    localMutationTransaction: LocalMutationTransaction(database),
    idGenerator: _SequenceIdGenerator(),
    clock: FixedAppClock(DateTime.utc(2026, 9, 1, 8)),
  );
}

Future<CustomerSummary> _create(
  DriftCustomersRepository repository, {
  required String name,
  required String operationId,
  String? email,
  bool enableLoyalty = false,
}) async {
  final result = await repository.createCustomer(
    context: _context,
    draft: CustomerDraft(
      displayName: name,
      email: email,
      enableLoyalty: enableLoyalty,
      operationId: operationId,
    ),
  );
  expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
  return _refresh(repository, result.valueOrNull!);
}

Future<CustomerSummary> _refresh(
  DriftCustomersRepository repository,
  String customerId,
) async {
  final customers = await repository
      .watchCustomers(context: _context, includeInactive: true)
      .first;
  return customers.singleWhere((customer) => customer.id == customerId);
}

Future<void> _insertSale(
  AppDatabase database, {
  required String id,
  String? customerId,
}) async {
  final now = DateTime.utc(2026, 9, 1, 9);
  await database
      .into(database.sales)
      .insert(
        SalesCompanion.insert(
          id: id,
          organizationId: 'organization',
          branchId: 'branch',
          registerId: 'register',
          customerId: Value(customerId),
          operationId: 'operation-$id',
          receiptNumber: Value('RECEIPT-$id'),
          status: const Value('completed'),
          cashierUserId: 'user',
          totalMinor: const Value(10000),
          tenderedMinor: const Value(10000),
          completedAt: Value(now),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _seed(AppDatabase database) async {
  final now = DateTime.utc(2026, 9, 1);
  await database
      .into(database.organizations)
      .insert(
        OrganizationsCompanion.insert(
          id: 'organization',
          code: 'JCE',
          name: 'JCE',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.branches)
      .insert(
        BranchesCompanion.insert(
          id: 'branch',
          organizationId: 'organization',
          code: 'MAIN',
          name: 'Main Branch',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.appUsers)
      .insert(
        AppUsersCompanion.insert(
          id: 'user',
          organizationId: 'organization',
          email: 'staff@jce.test',
          displayName: 'Staff User',
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.registers)
      .insert(
        RegistersCompanion.insert(
          id: 'register',
          organizationId: 'organization',
          branchId: 'branch',
          code: 'REG',
          name: 'Register',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

class _SequenceIdGenerator implements IdGenerator {
  var _value = 0;

  @override
  String newId() => 'phase12-${(_value++).toString().padLeft(8, '0')}';
}
