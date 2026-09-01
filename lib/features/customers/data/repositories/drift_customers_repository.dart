import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customers_repository.dart';
import '../data_sources/customers_local_data_source.dart';

class DriftCustomersRepository implements CustomersRepository {
  const DriftCustomersRepository({
    required db.AppDatabase database,
    required CustomersLocalDataSource localDataSource,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _database = database,
       _localDataSource = localDataSource,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock;

  final db.AppDatabase _database;
  final CustomersLocalDataSource _localDataSource;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  @override
  Stream<List<CustomerSummary>> watchCustomers({
    required BusinessContext context,
    String search = '',
    bool includeInactive = false,
  }) => _localDataSource.watchCustomers(
    organizationId: context.organizationId,
    search: search,
    includeInactive: includeInactive,
  );

  @override
  Stream<CustomerProfile?> watchCustomerProfile({
    required BusinessContext context,
    required String customerId,
  }) => _localDataSource.watchCustomerProfile(
    organizationId: context.organizationId,
    branchId: context.branchId,
    customerId: customerId,
  );

  @override
  Future<Result<String, Failure>> createCustomer({
    required BusinessContext context,
    required CustomerDraft draft,
  }) async {
    final operationId = draft.operationId ?? _idGenerator.newId();
    final existing = await _existingOperation(operationId);
    if (existing != null) {
      return existing.commandType == 'customer.create'
          ? Result.success(existing.aggregateId)
          : const Result.failure(
              ConflictFailure('The operation ID belongs to another action.'),
            );
    }
    final validation = _validateDraft(draft);
    if (validation != null) return Result.failure(validation);
    final duplicate = await _findDuplicate(
      context,
      email: _normalizeEmail(draft.email),
      phone: _normalizePhone(draft.phone),
    );
    if (duplicate != null && !draft.allowDuplicateContact) {
      return Result.failure(
        ConflictFailure(
          'Contact details already belong to ${duplicate.displayName} '
          '(${duplicate.customerNumber}). Merge the records or explicitly '
          'allow a duplicate.',
        ),
      );
    }
    final customerId = _idGenerator.newId();
    final accountId = draft.enableLoyalty ? _idGenerator.newId() : null;
    final addresses = _addressPayloads(draft.addresses);
    final now = _clock.nowUtc();
    final customerNumber = _customerNumber(customerId);
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await database
            .into(database.customers)
            .insert(
              db.CustomersCompanion.insert(
                id: customerId,
                organizationId: context.organizationId,
                customerNumber: customerNumber,
                displayName: draft.displayName.trim(),
                normalizedName: _normalizeSearch(draft.displayName),
                email: Value(_trimmed(draft.email)),
                normalizedEmail: Value(_normalizeEmail(draft.email)),
                phone: Value(_trimmed(draft.phone)),
                normalizedPhone: Value(_normalizePhone(draft.phone)),
                birthDate: Value(draft.birthDate?.toUtc()),
                marketingConsent: Value(draft.marketingConsent),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _replaceAddresses(database, context, customerId, addresses, now);
        if (accountId != null) {
          await database
              .into(database.loyaltyAccounts)
              .insert(
                db.LoyaltyAccountsCompanion.insert(
                  id: accountId,
                  organizationId: context.organizationId,
                  customerId: customerId,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
        return customerId;
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.create,
        customerId,
        now,
        {'customerNumber': customerNumber, 'loyaltyEnabled': accountId != null},
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'customer.create',
        'customer',
        customerId,
        now,
        {
          'id': customerId,
          'customerNumber': customerNumber,
          ..._customerFields(draft),
          'allowDuplicateContact': draft.allowDuplicateContact,
          'addresses': addresses,
          'loyaltyAccountId': accountId,
        },
      ),
    );
  }

  @override
  Future<Result<void, Failure>> updateCustomer({
    required BusinessContext context,
    required CustomerSummary customer,
    required CustomerDraft draft,
  }) async {
    final operationId = draft.operationId ?? _idGenerator.newId();
    final duplicateOperation = await _duplicateVoid(
      operationId,
      'customer',
      customer.id,
    );
    if (duplicateOperation != null) return duplicateOperation;
    final validation = _validateDraft(draft);
    if (validation != null) return Result.failure(validation);
    final duplicate = await _findDuplicate(
      context,
      email: _normalizeEmail(draft.email),
      phone: _normalizePhone(draft.phone),
      excludingId: customer.id,
    );
    if (duplicate != null && !draft.allowDuplicateContact) {
      return Result.failure(
        ConflictFailure(
          'Contact details already belong to ${duplicate.displayName} '
          '(${duplicate.customerNumber}).',
        ),
      );
    }
    final addresses = _addressPayloads(draft.addresses);
    final existingAccount = await (_database.select(
      _database.loyaltyAccounts,
    )..where((row) => row.customerId.equals(customer.id))).getSingleOrNull();
    final loyaltyAccountId = draft.enableLoyalty
        ? existingAccount?.id ?? _idGenerator.newId()
        : null;
    final now = _clock.nowUtc();
    final dependency = await _latestCustomerOperation(customer.id);
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final current = await _requireCustomer(database, context, customer.id);
        if (current.version != customer.version ||
            current.status == 'merged' ||
            current.status == 'anonymized') {
          throw _customerVersionConflict;
        }
        final changed =
            await (database.update(database.customers)..where(
                  (row) =>
                      row.id.equals(customer.id) &
                      row.version.equals(customer.version),
                ))
                .write(
                  db.CustomersCompanion(
                    displayName: Value(draft.displayName.trim()),
                    normalizedName: Value(_normalizeSearch(draft.displayName)),
                    email: Value(_trimmed(draft.email)),
                    normalizedEmail: Value(_normalizeEmail(draft.email)),
                    phone: Value(_trimmed(draft.phone)),
                    normalizedPhone: Value(_normalizePhone(draft.phone)),
                    birthDate: Value(draft.birthDate?.toUtc()),
                    marketingConsent: Value(draft.marketingConsent),
                    version: Value(customer.version + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) throw _customerVersionConflict;
        await _replaceAddresses(database, context, customer.id, addresses, now);
        if (draft.enableLoyalty) {
          await _ensureLoyaltyAccount(
            database,
            context,
            customer.id,
            now,
            preferredId: loyaltyAccountId,
          );
        }
      },
      auditEntry: _audit(
        context,
        operationId,
        AuditActionType.update,
        customer.id,
        now,
        {'event': 'profile_updated'},
      ),
      outboxCommand: _outbox(
        context,
        operationId,
        'customer.update',
        'customer',
        customer.id,
        now,
        {
          'id': customer.id,
          'expectedVersion': customer.version,
          ..._customerFields(draft),
          'allowDuplicateContact': draft.allowDuplicateContact,
          'addresses': addresses,
          'enableLoyalty': draft.enableLoyalty,
          'loyaltyAccountId': loyaltyAccountId,
        },
        dependsOnOperationId: dependency,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> archiveCustomer({
    required BusinessContext context,
    required CustomerSummary customer,
    String? operationId,
  }) => _setStatus(
    context: context,
    customer: customer,
    expectedStatus: CustomerStatus.active,
    nextStatus: CustomerStatus.archived,
    commandType: 'customer.archive',
    operationId: operationId,
  );

  @override
  Future<Result<void, Failure>> restoreCustomer({
    required BusinessContext context,
    required CustomerSummary customer,
    String? operationId,
  }) => _setStatus(
    context: context,
    customer: customer,
    expectedStatus: CustomerStatus.archived,
    nextStatus: CustomerStatus.active,
    commandType: 'customer.restore',
    operationId: operationId,
  );

  @override
  Future<Result<void, Failure>> anonymizeCustomer({
    required BusinessContext context,
    required CustomerSummary customer,
    required String reason,
    String? operationId,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.length < 5) {
      return const Result.failure(
        ValidationFailure('A clear anonymization reason is required.'),
      );
    }
    final operation = operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateVoid(operation, 'customer', customer.id);
    if (duplicate != null) return duplicate;
    final dependency = await _latestCustomerOperation(customer.id);
    final now = _clock.nowUtc();
    final anonymizedName = 'Anonymized ${customer.customerNumber}';
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final current = await _requireCustomer(database, context, customer.id);
        if (current.version != customer.version ||
            current.status == 'merged' ||
            current.status == 'anonymized') {
          throw _customerVersionConflict;
        }
        final changed =
            await (database.update(database.customers)..where(
                  (row) =>
                      row.id.equals(customer.id) &
                      row.version.equals(customer.version),
                ))
                .write(
                  db.CustomersCompanion(
                    displayName: Value(anonymizedName),
                    normalizedName: Value(_normalizeSearch(anonymizedName)),
                    email: const Value(null),
                    normalizedEmail: const Value(null),
                    phone: const Value(null),
                    normalizedPhone: const Value(null),
                    birthDate: const Value(null),
                    marketingConsent: const Value(false),
                    status: const Value('anonymized'),
                    anonymizedAt: Value(now),
                    version: Value(customer.version + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) throw _customerVersionConflict;
        await (database.update(
          database.customerAddresses,
        )..where((row) => row.customerId.equals(customer.id))).write(
          db.CustomerAddressesCompanion(
            recipientName: const Value(null),
            lineOne: const Value('[anonymized]'),
            lineTwo: const Value(null),
            city: const Value('[anonymized]'),
            province: const Value(null),
            postalCode: const Value(null),
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await (database.update(
          database.customerNotes,
        )..where((row) => row.customerId.equals(customer.id))).write(
          db.CustomerNotesCompanion(
            body: const Value('[anonymized]'),
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await (database.update(
          database.loyaltyAccounts,
        )..where((row) => row.customerId.equals(customer.id))).write(
          db.LoyaltyAccountsCompanion(
            status: const Value('closed'),
            closedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      },
      auditEntry: _audit(
        context,
        operation,
        AuditActionType.delete,
        customer.id,
        now,
        {'event': 'anonymized', 'reason': normalizedReason},
      ),
      outboxCommand: _outbox(
        context,
        operation,
        'customer.anonymize',
        'customer',
        customer.id,
        now,
        {
          'id': customer.id,
          'expectedVersion': customer.version,
          'reason': normalizedReason,
        },
        dependsOnOperationId: dependency,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> mergeCustomers({
    required BusinessContext context,
    required CustomerSummary source,
    required CustomerSummary target,
    String? operationId,
  }) async {
    if (source.id == target.id) {
      return const Result.failure(
        ValidationFailure('A customer cannot be merged into itself.'),
      );
    }
    if (!source.canTransact || !target.canTransact) {
      return const Result.failure(
        ValidationFailure('Only active customer records can be merged.'),
      );
    }
    final operation = operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateVoid(operation, 'customer', source.id);
    if (duplicate != null) return duplicate;
    final dependency = await _latestCustomerOperation(source.id);
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final sourceRow = await _requireCustomer(database, context, source.id);
        final targetRow = await _requireCustomer(database, context, target.id);
        if (sourceRow.version != source.version ||
            targetRow.version != target.version ||
            sourceRow.status != 'active' ||
            targetRow.status != 'active') {
          throw _customerVersionConflict;
        }
        await database.customUpdate(
          'UPDATE customer_addresses SET customer_id = ?, version = version + 1, '
          'updated_at = ? WHERE customer_id = ? AND organization_id = ?',
          variables: [
            Variable<String>(target.id),
            Variable<DateTime>(now),
            Variable<String>(source.id),
            Variable<String>(context.organizationId),
          ],
          updates: {database.customerAddresses},
        );
        await database.customUpdate(
          'UPDATE customer_notes SET customer_id = ?, updated_at = ? '
          'WHERE customer_id = ? AND organization_id = ?',
          variables: [
            Variable<String>(target.id),
            Variable<DateTime>(now),
            Variable<String>(source.id),
            Variable<String>(context.organizationId),
          ],
          updates: {database.customerNotes},
        );
        await (database.update(database.sales)..where(
              (row) =>
                  row.customerId.equals(source.id) &
                  row.organizationId.equals(context.organizationId),
            ))
            .write(
              db.SalesCompanion(
                customerId: Value(target.id),
                updatedAt: Value(now),
              ),
            );
        await _mergeLoyalty(
          database,
          context,
          source.id,
          target.id,
          operation,
          now,
        );
        final targetChanged =
            await (database.update(database.customers)..where(
                  (row) =>
                      row.id.equals(target.id) &
                      row.version.equals(target.version),
                ))
                .write(
                  db.CustomersCompanion(
                    email: Value(targetRow.email ?? sourceRow.email),
                    normalizedEmail: Value(
                      targetRow.normalizedEmail ?? sourceRow.normalizedEmail,
                    ),
                    phone: Value(targetRow.phone ?? sourceRow.phone),
                    normalizedPhone: Value(
                      targetRow.normalizedPhone ?? sourceRow.normalizedPhone,
                    ),
                    version: Value(target.version + 1),
                    updatedAt: Value(now),
                  ),
                );
        final sourceChanged =
            await (database.update(database.customers)..where(
                  (row) =>
                      row.id.equals(source.id) &
                      row.version.equals(source.version),
                ))
                .write(
                  db.CustomersCompanion(
                    status: const Value('merged'),
                    mergedIntoCustomerId: Value(target.id),
                    marketingConsent: const Value(false),
                    archivedAt: Value(now),
                    version: Value(source.version + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (targetChanged != 1 || sourceChanged != 1) {
          throw _customerVersionConflict;
        }
      },
      auditEntry: _audit(
        context,
        operation,
        AuditActionType.update,
        source.id,
        now,
        {'event': 'merged', 'targetCustomerId': target.id},
      ),
      outboxCommand: _outbox(
        context,
        operation,
        'customer.merge',
        'customer',
        source.id,
        now,
        {
          'id': source.id,
          'targetCustomerId': target.id,
          'sourceExpectedVersion': source.version,
          'targetExpectedVersion': target.version,
        },
        dependsOnOperationId: dependency,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> addNote({
    required BusinessContext context,
    required String customerId,
    required String body,
    String? operationId,
  }) async {
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty || normalizedBody.length > 2000) {
      return const Result.failure(
        ValidationFailure('Customer notes must contain 1 to 2,000 characters.'),
      );
    }
    final operation = operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateVoid(operation, 'customer', customerId);
    if (duplicate != null) return duplicate;
    final noteId = _idGenerator.newId();
    final dependency = await _latestCustomerOperation(customerId);
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final customer = await _requireCustomer(database, context, customerId);
        if (customer.status == 'merged' || customer.status == 'anonymized') {
          throw const ValidationFailure(
            'Notes cannot be added to this customer record.',
          );
        }
        await database
            .into(database.customerNotes)
            .insert(
              db.CustomerNotesCompanion.insert(
                id: noteId,
                organizationId: context.organizationId,
                branchId: context.branchId,
                customerId: customerId,
                body: normalizedBody,
                createdByUserId: context.actorUserId,
                createdAt: now,
                updatedAt: now,
              ),
            );
      },
      auditEntry: _audit(
        context,
        operation,
        AuditActionType.create,
        customerId,
        now,
        {'event': 'note_added', 'noteId': noteId},
      ),
      outboxCommand: _outbox(
        context,
        operation,
        'customer.note.add',
        'customer',
        customerId,
        now,
        {'id': customerId, 'noteId': noteId, 'body': normalizedBody},
        dependsOnOperationId: dependency,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> adjustLoyaltyPoints({
    required BusinessContext context,
    required String customerId,
    required int pointsDelta,
    required String reason,
    String? operationId,
  }) async {
    final normalizedReason = reason.trim();
    if (pointsDelta == 0 || normalizedReason.length < 3) {
      return const Result.failure(
        ValidationFailure(
          'A non-zero point adjustment and reason are required.',
        ),
      );
    }
    final operation = operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateVoid(
      operation,
      'loyalty_account',
      customerId,
    );
    if (duplicate != null) return duplicate;
    final dependency = await _latestCustomerOperation(customerId);
    final existingAccount = await (_database.select(
      _database.loyaltyAccounts,
    )..where((row) => row.customerId.equals(customerId))).getSingleOrNull();
    final loyaltyAccountId = existingAccount?.id ?? _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final customer = await _requireCustomer(database, context, customerId);
        if (customer.status != 'active') {
          throw const ValidationFailure(
            'Loyalty points can only be adjusted for active customers.',
          );
        }
        final account = await _ensureLoyaltyAccount(
          database,
          context,
          customerId,
          now,
          preferredId: loyaltyAccountId,
        );
        if (account.status != 'active') {
          throw const ValidationFailure('The loyalty account is not active.');
        }
        final balance = account.pointsBalance + pointsDelta;
        if (balance < 0) {
          throw const ValidationFailure(
            'The adjustment would make the loyalty balance negative.',
          );
        }
        final changed =
            await (database.update(database.loyaltyAccounts)..where(
                  (row) =>
                      row.id.equals(account.id) &
                      row.version.equals(account.version),
                ))
                .write(
                  db.LoyaltyAccountsCompanion(
                    pointsBalance: Value(balance),
                    version: Value(account.version + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) throw _loyaltyVersionConflict;
        await database
            .into(database.loyaltyLedgerEntries)
            .insert(
              db.LoyaltyLedgerEntriesCompanion.insert(
                id: _idGenerator.newId(),
                organizationId: context.organizationId,
                branchId: Value(context.branchId),
                accountId: account.id,
                operationId: operation,
                entryType: 'adjustment',
                pointsDelta: pointsDelta,
                balanceAfter: balance,
                reason: normalizedReason,
                referenceType: const Value('manual_adjustment'),
                referenceId: Value(operation),
                createdByUserId: context.actorUserId,
                occurredAt: now,
                createdAt: now,
              ),
            );
      },
      auditEntry:
          _audit(context, operation, AuditActionType.update, customerId, now, {
            'event': 'loyalty_adjustment',
            'pointsDelta': pointsDelta,
            'reason': normalizedReason,
          }),
      outboxCommand: _outbox(
        context,
        operation,
        'loyalty.adjust',
        'loyalty_account',
        customerId,
        now,
        {
          'customerId': customerId,
          'accountId': loyaltyAccountId,
          'pointsDelta': pointsDelta,
          'reason': normalizedReason,
          'occurredAt': now.toIso8601String(),
        },
        dependsOnOperationId: dependency,
      ),
    );
  }

  Future<Result<void, Failure>> _setStatus({
    required BusinessContext context,
    required CustomerSummary customer,
    required CustomerStatus expectedStatus,
    required CustomerStatus nextStatus,
    required String commandType,
    String? operationId,
  }) async {
    final operation = operationId ?? _idGenerator.newId();
    final duplicate = await _duplicateVoid(operation, 'customer', customer.id);
    if (duplicate != null) return duplicate;
    final dependency = await _latestCustomerOperation(customer.id);
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final current = await _requireCustomer(database, context, customer.id);
        if (current.version != customer.version ||
            current.status != expectedStatus.databaseValue) {
          throw _customerVersionConflict;
        }
        final changed =
            await (database.update(database.customers)..where(
                  (row) =>
                      row.id.equals(customer.id) &
                      row.version.equals(customer.version),
                ))
                .write(
                  db.CustomersCompanion(
                    status: Value(nextStatus.databaseValue),
                    archivedAt: Value(
                      nextStatus == CustomerStatus.archived ? now : null,
                    ),
                    version: Value(customer.version + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) throw _customerVersionConflict;
      },
      auditEntry: _audit(
        context,
        operation,
        AuditActionType.update,
        customer.id,
        now,
        {'event': nextStatus.databaseValue},
      ),
      outboxCommand: _outbox(
        context,
        operation,
        commandType,
        'customer',
        customer.id,
        now,
        {'id': customer.id, 'expectedVersion': customer.version},
        dependsOnOperationId: dependency,
      ),
    );
  }

  Future<void> _replaceAddresses(
    db.AppDatabase database,
    BusinessContext context,
    String customerId,
    List<Map<String, Object?>> addresses,
    DateTime now,
  ) async {
    await (database.update(database.customerAddresses)..where(
          (row) => row.customerId.equals(customerId) & row.deletedAt.isNull(),
        ))
        .write(
          db.CustomerAddressesCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final address in addresses) {
      await database
          .into(database.customerAddresses)
          .insertOnConflictUpdate(
            db.CustomerAddressesCompanion.insert(
              id: address['id']! as String,
              organizationId: context.organizationId,
              customerId: customerId,
              label: address['label']! as String,
              recipientName: Value(address['recipientName'] as String?),
              lineOne: address['lineOne']! as String,
              lineTwo: Value(address['lineTwo'] as String?),
              city: address['city']! as String,
              province: Value(address['province'] as String?),
              postalCode: Value(address['postalCode'] as String?),
              countryCode: Value(address['countryCode']! as String),
              isPrimary: Value(address['isPrimary']! as bool),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<db.LoyaltyAccount> _ensureLoyaltyAccount(
    db.AppDatabase database,
    BusinessContext context,
    String customerId,
    DateTime now, {
    String? preferredId,
  }) async {
    final existing =
        await (database.select(database.loyaltyAccounts)..where(
              (row) =>
                  row.customerId.equals(customerId) &
                  row.organizationId.equals(context.organizationId),
            ))
            .getSingleOrNull();
    if (existing != null) return existing;
    final id = preferredId ?? _idGenerator.newId();
    await database
        .into(database.loyaltyAccounts)
        .insert(
          db.LoyaltyAccountsCompanion.insert(
            id: id,
            organizationId: context.organizationId,
            customerId: customerId,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (database.select(
      database.loyaltyAccounts,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  Future<void> _mergeLoyalty(
    db.AppDatabase database,
    BusinessContext context,
    String sourceCustomerId,
    String targetCustomerId,
    String operationId,
    DateTime now,
  ) async {
    final source =
        await (database.select(database.loyaltyAccounts)
              ..where((row) => row.customerId.equals(sourceCustomerId)))
            .getSingleOrNull();
    if (source == null) return;
    final target =
        await (database.select(database.loyaltyAccounts)
              ..where((row) => row.customerId.equals(targetCustomerId)))
            .getSingleOrNull();
    if (target == null) {
      await (database.update(
        database.loyaltyAccounts,
      )..where((row) => row.id.equals(source.id))).write(
        db.LoyaltyAccountsCompanion(
          customerId: Value(targetCustomerId),
          version: Value(source.version + 1),
          updatedAt: Value(now),
        ),
      );
      return;
    }
    final points = source.pointsBalance;
    if (points > 0) {
      await database
          .into(database.loyaltyLedgerEntries)
          .insert(
            db.LoyaltyLedgerEntriesCompanion.insert(
              id: _idGenerator.newId(),
              organizationId: context.organizationId,
              branchId: Value(context.branchId),
              accountId: source.id,
              operationId: '$operationId:merge-out',
              entryType: 'merge_out',
              pointsDelta: -points,
              balanceAfter: 0,
              reason: 'Merged into customer $targetCustomerId',
              referenceType: const Value('customer_merge'),
              referenceId: Value(targetCustomerId),
              createdByUserId: context.actorUserId,
              occurredAt: now,
              createdAt: now,
            ),
          );
      await database
          .into(database.loyaltyLedgerEntries)
          .insert(
            db.LoyaltyLedgerEntriesCompanion.insert(
              id: _idGenerator.newId(),
              organizationId: context.organizationId,
              branchId: Value(context.branchId),
              accountId: target.id,
              operationId: '$operationId:merge-in',
              entryType: 'merge_in',
              pointsDelta: points,
              balanceAfter: target.pointsBalance + points,
              reason: 'Merged from customer $sourceCustomerId',
              referenceType: const Value('customer_merge'),
              referenceId: Value(sourceCustomerId),
              createdByUserId: context.actorUserId,
              occurredAt: now,
              createdAt: now,
            ),
          );
    }
    await (database.update(
      database.loyaltyAccounts,
    )..where((row) => row.id.equals(source.id))).write(
      db.LoyaltyAccountsCompanion(
        status: const Value('merged'),
        pointsBalance: const Value(0),
        closedAt: Value(now),
        version: Value(source.version + 1),
        updatedAt: Value(now),
      ),
    );
    await (database.update(
      database.loyaltyAccounts,
    )..where((row) => row.id.equals(target.id))).write(
      db.LoyaltyAccountsCompanion(
        pointsBalance: Value(target.pointsBalance + points),
        version: Value(target.version + 1),
        updatedAt: Value(now),
      ),
    );
  }

  Future<db.Customer> _requireCustomer(
    db.AppDatabase database,
    BusinessContext context,
    String customerId,
  ) async {
    final customer =
        await (database.select(database.customers)..where(
              (row) =>
                  row.id.equals(customerId) &
                  row.organizationId.equals(context.organizationId),
            ))
            .getSingleOrNull();
    if (customer == null) {
      throw const AuthorizationFailure(
        'The customer is outside the active organization.',
      );
    }
    return customer;
  }

  Future<db.Customer?> _findDuplicate(
    BusinessContext context, {
    String? email,
    String? phone,
    String? excludingId,
  }) async {
    if (email == null && phone == null) return null;
    final query = _database.select(_database.customers)
      ..where((row) {
        Expression<bool> contacts = const Constant(false);
        if (email != null) {
          contacts = contacts | row.normalizedEmail.equals(email);
        }
        if (phone != null) {
          contacts = contacts | row.normalizedPhone.equals(phone);
        }
        var predicate =
            row.organizationId.equals(context.organizationId) &
            row.status.isIn(const ['active', 'archived']) &
            contacts;
        if (excludingId != null) {
          predicate = predicate & row.id.equals(excludingId).not();
        }
        return predicate;
      })
      ..limit(1);
    return query.getSingleOrNull();
  }

  Failure? _validateDraft(CustomerDraft draft) {
    if (draft.displayName.trim().length < 2) {
      return const ValidationFailure(
        'Customer name must contain at least two characters.',
      );
    }
    final email = _normalizeEmail(draft.email);
    if (email != null &&
        (!email.contains('@') ||
            email.startsWith('@') ||
            email.endsWith('@'))) {
      return const ValidationFailure('Enter a valid customer email address.');
    }
    final phone = _normalizePhone(draft.phone);
    if (phone != null && phone.length < 7) {
      return const ValidationFailure(
        'Customer phone numbers must contain at least seven digits.',
      );
    }
    if (draft.birthDate?.isAfter(_clock.nowUtc()) ?? false) {
      return const ValidationFailure('Birth date cannot be in the future.');
    }
    if (draft.addresses.where((address) => address.isPrimary).length > 1 ||
        draft.addresses.any(
          (address) =>
              address.label.trim().isEmpty ||
              address.lineOne.trim().isEmpty ||
              address.city.trim().isEmpty ||
              address.countryCode.trim().length != 2,
        )) {
      return const ValidationFailure(
        'Addresses require a label, street, city, two-letter country code, '
        'and at most one primary address.',
      );
    }
    return null;
  }

  List<Map<String, Object?>> _addressPayloads(
    List<CustomerAddressDraft> addresses,
  ) => [
    for (final address in addresses)
      {
        'id': address.id ?? _idGenerator.newId(),
        'label': address.label.trim(),
        'recipientName': _trimmed(address.recipientName),
        'lineOne': address.lineOne.trim(),
        'lineTwo': _trimmed(address.lineTwo),
        'city': address.city.trim(),
        'province': _trimmed(address.province),
        'postalCode': _trimmed(address.postalCode),
        'countryCode': address.countryCode.trim().toUpperCase(),
        'isPrimary': address.isPrimary,
      },
  ];

  Map<String, Object?> _customerFields(CustomerDraft draft) => {
    'displayName': draft.displayName.trim(),
    'email': _trimmed(draft.email),
    'normalizedEmail': _normalizeEmail(draft.email),
    'phone': _trimmed(draft.phone),
    'normalizedPhone': _normalizePhone(draft.phone),
    'birthDate': draft.birthDate?.toUtc().toIso8601String(),
    'marketingConsent': draft.marketingConsent,
  };

  Future<db.SyncOutboxEntry?> _existingOperation(String operationId) =>
      (_database.select(
        _database.syncOutboxEntries,
      )..where((row) => row.operationId.equals(operationId))).getSingleOrNull();

  Future<Result<void, Failure>?> _duplicateVoid(
    String operationId,
    String aggregateType,
    String aggregateId,
  ) async {
    final operation = await _existingOperation(operationId);
    if (operation == null) return null;
    return operation.aggregateType == aggregateType &&
            operation.aggregateId == aggregateId
        ? const Result.success(null)
        : const Result.failure(
            ConflictFailure('The operation ID belongs to another action.'),
          );
  }

  Future<String?> _latestCustomerOperation(String customerId) async {
    final rows =
        await (_database.select(_database.syncOutboxEntries)
              ..where(
                (row) =>
                    ((row.aggregateType.equals('customer') &
                        row.aggregateId.equals(customerId)) |
                    (row.aggregateType.equals('loyalty_account') &
                        row.aggregateId.equals(customerId))),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(1))
            .get();
    return rows.firstOrNull?.operationId;
  }

  AuditLogEntry _audit(
    BusinessContext context,
    String operationId,
    AuditActionType action,
    String customerId,
    DateTime now,
    Map<String, Object?> metadata,
  ) => AuditLogEntry(
    id: _idGenerator.newId(),
    operationId: operationId,
    organizationId: context.organizationId,
    branchId: context.branchId,
    actorUserId: context.actorUserId,
    actionType: action,
    entityName: 'customer',
    entityId: customerId,
    metadata: metadata,
    createdAt: now,
  );

  OutboxCommand _outbox(
    BusinessContext context,
    String operationId,
    String commandType,
    String aggregateType,
    String aggregateId,
    DateTime now,
    Map<String, Object?> payload, {
    String? dependsOnOperationId,
  }) => OutboxCommand(
    operationId: operationId,
    organizationId: context.organizationId,
    branchId: context.branchId,
    actorUserId: context.actorUserId,
    commandType: commandType,
    aggregateType: aggregateType,
    aggregateId: aggregateId,
    dependsOnOperationId: dependsOnOperationId,
    payload: payload,
    createdAt: now,
  );
}

const _customerVersionConflict = ConflictFailure(
  'The customer record changed after it was opened. Refresh and retry.',
);

const _loyaltyVersionConflict = ConflictFailure(
  'The loyalty balance changed. Refresh and retry.',
);

String _normalizeSearch(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

String? _normalizeEmail(String? value) => _trimmed(value)?.toLowerCase();

String? _normalizePhone(String? value) {
  final phone = _trimmed(value)?.replaceAll(RegExp('[^0-9]'), '');
  return phone == null || phone.isEmpty ? null : phone;
}

String? _trimmed(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _customerNumber(String id) {
  final normalized = id.replaceAll('-', '').toUpperCase().padLeft(8, '0');
  return 'CUS-${normalized.substring(normalized.length - 8)}';
}
