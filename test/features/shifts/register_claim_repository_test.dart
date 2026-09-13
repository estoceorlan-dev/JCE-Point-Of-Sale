import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/database/models/outbox_state.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/shifts/data/repositories/drift_register_claim_repository.dart';

void main() {
  test(
    'claim resolution atomically rebases only the unsynced claim chain',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final clock = FixedAppClock(_stamp);
      final repository = DriftRegisterClaimRepository(
        database: database,
        localMutationTransaction: LocalMutationTransaction(database),
        idGenerator: const FixedIdGenerator('unused'),
        clock: clock,
      );
      try {
        await _seedRejectedClaimChain(database);

        await repository.applyResolutionDirective(
          organizationId: 'organization',
          branchId: 'branch',
          claimId: 'claim',
          targetRegisterId: 'register-new',
          deviceId: 'device',
          managerUserId: 'manager',
          resolvedAt: _stamp,
        );

        final claim = await database
            .select(database.registerClaims)
            .getSingle();
        final shift = await database.select(database.shifts).getSingle();
        final movement = await database
            .select(database.cashMovements)
            .getSingle();
        final sale = await database.select(database.sales).getSingle();
        final printJob = await database
            .select(database.receiptPrintJobs)
            .getSingle();
        final registers = {
          for (final register
              in await database.select(database.registers).get())
            register.id: register,
        };
        final outbox = {
          for (final command
              in await database.select(database.syncOutboxEntries).get())
            command.operationId: command,
        };

        expect(claim.status, 'resolved');
        expect(claim.resolvedRegisterId, 'register-new');
        expect(claim.resolvedByUserId, 'manager');
        expect(shift.registerId, 'register-new');
        expect(movement.registerId, 'register-new');
        expect(sale.registerId, 'register-new');
        expect(printJob.registerId, 'register-new');
        expect(printJob.documentText, contains('register-old'));
        expect(registers['register-old']!.assignedDeviceId, isNull);
        expect(registers['register-new']!.assignedDeviceId, 'device');
        expect(outbox['claim']!.status, OutboxState.succeeded.databaseValue);
        expect(
          outbox['sale-operation']!.status,
          OutboxState.pending.databaseValue,
        );
        expect(
          jsonDecode(outbox['sale-operation']!.payloadJson)['registerId'],
          'register-new',
        );
        expect(
          jsonDecode(outbox['unrelated-operation']!.payloadJson)['registerId'],
          'register-old',
        );
      } finally {
        await database.close();
      }
    },
  );
}

final _stamp = DateTime.utc(2026, 9, 13, 8);

Future<void> _seedRejectedClaimChain(AppDatabase database) async {
  await database
      .into(database.organizations)
      .insert(
        OrganizationsCompanion.insert(
          id: 'organization',
          code: 'ORG',
          name: 'Organization',
          createdAt: _stamp,
          updatedAt: _stamp,
        ),
      );
  await database
      .into(database.branches)
      .insert(
        BranchesCompanion.insert(
          id: 'branch',
          organizationId: 'organization',
          code: 'MAIN',
          name: 'Main',
          createdAt: _stamp,
          updatedAt: _stamp,
        ),
      );
  for (final id in ['register-old', 'register-new']) {
    await database
        .into(database.registers)
        .insert(
          RegistersCompanion.insert(
            id: id,
            organizationId: 'organization',
            branchId: 'branch',
            code: id,
            name: id,
            assignedDeviceId: Value(id == 'register-old' ? 'device' : null),
            assignedByUserId: Value(id == 'register-old' ? 'cashier' : null),
            assignedAt: Value(id == 'register-old' ? _stamp : null),
            createdAt: _stamp,
            updatedAt: _stamp,
          ),
        );
  }
  await database
      .into(database.registerClaims)
      .insert(
        RegisterClaimsCompanion.insert(
          id: 'claim',
          organizationId: 'organization',
          branchId: 'branch',
          requestedRegisterId: 'register-old',
          deviceId: 'device',
          claimedByUserId: 'cashier',
          status: 'rejected',
          rejectionCode: const Value('register_already_claimed'),
          createdAt: _stamp,
          updatedAt: _stamp,
        ),
      );
  await database
      .into(database.shifts)
      .insert(
        ShiftsCompanion.insert(
          id: 'shift',
          organizationId: 'organization',
          branchId: 'branch',
          registerId: 'register-old',
          deviceId: 'device',
          operationId: 'shift-operation',
          registerClaimId: const Value('claim'),
          openingCashMinor: 10000,
          openedByUserId: 'cashier',
          openedAt: _stamp,
          createdAt: _stamp,
          updatedAt: _stamp,
        ),
      );
  await database
      .into(database.cashMovements)
      .insert(
        CashMovementsCompanion.insert(
          id: 'movement',
          organizationId: 'organization',
          branchId: 'branch',
          registerId: 'register-old',
          shiftId: 'shift',
          operationId: 'movement-operation',
          registerClaimId: const Value('claim'),
          movementType: 'cash_in',
          amountMinor: 1000,
          reason: 'Float',
          createdByUserId: 'cashier',
          occurredAt: _stamp,
          createdAt: _stamp,
        ),
      );
  await database
      .into(database.sales)
      .insert(
        SalesCompanion.insert(
          id: 'sale',
          organizationId: 'organization',
          branchId: 'branch',
          registerId: 'register-old',
          shiftId: const Value('shift'),
          operationId: 'sale-operation',
          registerClaimId: const Value('claim'),
          receiptNumber: const Value('register-old-0001'),
          status: const Value('completed'),
          cashierUserId: 'cashier',
          completedAt: Value(_stamp),
          createdAt: _stamp,
          updatedAt: _stamp,
        ),
      );
  await database
      .into(database.receiptPrintJobs)
      .insert(
        ReceiptPrintJobsCompanion.insert(
          id: 'print',
          organizationId: 'organization',
          branchId: 'branch',
          registerId: 'register-old',
          registerClaimId: const Value('claim'),
          saleId: 'sale',
          deduplicationKey: 'sale:original',
          copyType: 'original',
          documentText: 'Offline receipt register-old-0001',
          requestedByUserId: 'cashier',
          createdAt: _stamp,
          updatedAt: _stamp,
        ),
      );
  for (final operation in [
    (
      id: 'claim',
      causalGroupId: 'claim',
      registerId: 'register-old',
      status: OutboxState.conflict,
    ),
    (
      id: 'sale-operation',
      causalGroupId: 'claim',
      registerId: 'register-old',
      status: OutboxState.conflict,
    ),
    (
      id: 'unrelated-operation',
      causalGroupId: 'another-claim',
      registerId: 'register-old',
      status: OutboxState.pending,
    ),
  ]) {
    await database
        .into(database.syncOutboxEntries)
        .insert(
          SyncOutboxEntriesCompanion.insert(
            operationId: operation.id,
            organizationId: const Value('organization'),
            branchId: const Value('branch'),
            actorUserId: const Value('cashier'),
            commandType: operation.id == 'claim'
                ? 'register.claim'
                : 'sale.complete',
            aggregateType: operation.id == 'claim' ? 'register_claim' : 'sale',
            aggregateId: operation.id == 'claim' ? 'claim' : 'sale',
            causalGroupId: Value(operation.causalGroupId),
            payloadJson: jsonEncode({'registerId': operation.registerId}),
            status: operation.status.databaseValue,
            createdAt: _stamp,
            updatedAt: _stamp,
          ),
        );
  }
}
