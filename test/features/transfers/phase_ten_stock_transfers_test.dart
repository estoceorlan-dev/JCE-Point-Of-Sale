import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart'
    hide AppUser, Organization, StockTransfer;
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/remote/remote_sync_data_source.dart';
import 'package:jce_pos/core/sync/operations_change_applier.dart';
import 'package:jce_pos/core/sync/remote_change_envelope.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/auth/domain/entities/auth_session.dart';
import 'package:jce_pos/features/auth/domain/usecases/require_permission_usecase.dart';
import 'package:jce_pos/features/transfers/data/data_sources/transfers_local_data_source.dart';
import 'package:jce_pos/features/transfers/data/repositories/drift_transfers_repository.dart';
import 'package:jce_pos/features/transfers/domain/entities/stock_transfer.dart';
import 'package:jce_pos/features/transfers/domain/use_cases/transfer_workflow_use_case.dart';
import 'package:jce_pos/shared/models/access_role.dart';
import 'package:jce_pos/shared/models/app_user.dart';
import 'package:jce_pos/shared/models/branch.dart';
import 'package:jce_pos/shared/models/branch_access.dart';
import 'package:jce_pos/shared/models/business_context.dart';
import 'package:jce_pos/shared/models/organization.dart';
import 'package:jce_pos/shared/models/organization_access.dart';
import 'package:jce_pos/shared/models/permission.dart';
import 'package:jce_pos/shared/models/user_account_status.dart';

void main() {
  group('Phase 10 stock transfers', () {
    late AppDatabase database;
    late DriftTransfersRepository repository;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      await _seed(database);
      repository = _repository(database);
    });

    tearDown(() => database.close());

    test('source and destination branches must differ', () async {
      final result = await repository.createDraft(
        context: _sourceContext,
        draft: const StockTransferDraft(
          destinationBranchId: 'source',
          operationId: 'invalid-same-branch',
          lines: [
            StockTransferLineDraft(
              productId: 'product',
              sourceStockLocationId: 'source-location',
              destinationStockLocationId: 'source-location',
              quantityMilli: 1000,
            ),
          ],
        ),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await database.select(database.stockTransfers).get(), isEmpty);
    });

    test('invalid state transitions are rejected atomically', () async {
      final transfer = await _createTransfer(repository, quantity: 2000);

      final result = await repository.ship(
        context: _sourceContext,
        transferId: transfer.id,
        expectedVersion: transfer.version,
        operationId: 'ship-draft',
      );

      expect(result.failureOrNull, isA<ConflictFailure>());
      expect(
        await database.select(database.inventoryTransactions).get(),
        isEmpty,
      );
      expect(
        await database.select(database.transferEvents).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.syncOutboxEntries).get(),
        hasLength(1),
      );
    });

    test('shipment and full receipt ledger entries balance', () async {
      var transfer = await _createTransfer(repository, quantity: 3000);
      expect(
        (await repository.submit(
          context: _sourceContext,
          transferId: transfer.id,
          expectedVersion: transfer.version,
          operationId: 'submit-transfer',
        )).isSuccess,
        isTrue,
      );
      transfer = (await repository.getTransfer(
        context: _sourceContext,
        transferId: transfer.id,
      ))!;
      expect(transfer.status, StockTransferStatus.approved);
      expect((await _balance(database, 'source-location')).reservedMilli, 3000);

      expect(
        (await repository.ship(
          context: _sourceContext,
          transferId: transfer.id,
          expectedVersion: transfer.version,
          operationId: 'ship-transfer',
        )).isSuccess,
        isTrue,
      );
      transfer = (await repository.getTransfer(
        context: _destinationContext,
        transferId: transfer.id,
      ))!;
      expect(
        (await repository.receive(
          context: _destinationContext,
          transferId: transfer.id,
          expectedVersion: transfer.version,
          draft: TransferReceiptDraft(
            operationId: 'receive-transfer',
            lines: [
              TransferReceiptLineDraft(
                transferItemId: transfer.lines.single.id,
                receivedQuantityMilli: 3000,
                damagedQuantityMilli: 0,
              ),
            ],
          ),
        )).isSuccess,
        isTrue,
      );

      expect((await _balance(database, 'source-location')).onHandMilli, 7000);
      expect((await _balance(database, 'source-location')).reservedMilli, 0);
      expect(
        (await _balance(database, 'destination-location')).onHandMilli,
        3000,
      );
      final ledger = await database
          .select(database.inventoryLedgerEntries)
          .get();
      expect(
        ledger.map((row) => row.quantityDeltaMilli).fold(0, (a, b) => a + b),
        0,
      );
      expect(
        (await repository.getTransfer(
          context: _destinationContext,
          transferId: transfer.id,
        ))!.status,
        StockTransferStatus.received,
      );
      final commands = await database.select(database.syncOutboxEntries).get();
      expect(
        commands
            .singleWhere((row) => row.operationId == 'submit-transfer')
            .dependsOnOperationId,
        'create-3000',
      );
      expect(
        commands
            .singleWhere((row) => row.operationId == 'ship-transfer')
            .dependsOnOperationId,
        'submit-transfer',
      );
      expect(
        commands
            .singleWhere((row) => row.operationId == 'receive-transfer')
            .dependsOnOperationId,
        'ship-transfer',
      );
    });

    test(
      'receipt records damaged stock and explicit discrepancy custody',
      () async {
        var transfer = await _createTransfer(repository, quantity: 3000);
        await repository.submit(
          context: _sourceContext,
          transferId: transfer.id,
          expectedVersion: transfer.version,
          operationId: 'submit-discrepancy',
        );
        transfer = (await repository.getTransfer(
          context: _sourceContext,
          transferId: transfer.id,
        ))!;
        await repository.ship(
          context: _sourceContext,
          transferId: transfer.id,
          expectedVersion: transfer.version,
          operationId: 'ship-discrepancy',
        );
        transfer = (await repository.getTransfer(
          context: _destinationContext,
          transferId: transfer.id,
        ))!;

        final result = await repository.receive(
          context: _destinationContext,
          transferId: transfer.id,
          expectedVersion: transfer.version,
          draft: TransferReceiptDraft(
            operationId: 'receive-discrepancy',
            lines: [
              TransferReceiptLineDraft(
                transferItemId: transfer.lines.single.id,
                receivedQuantityMilli: 2500,
                damagedQuantityMilli: 200,
                damagedStockLocationId: 'damaged-location',
              ),
            ],
          ),
        );

        expect(result.isSuccess, isTrue);
        final received = (await repository.getTransfer(
          context: _destinationContext,
          transferId: transfer.id,
        ))!;
        expect(received.lines.single.discrepancyQuantityMilli, 300);
        expect(received.lines.single.inTransitQuantityMilli, 300);
        expect(
          (await _balance(database, 'destination-location')).onHandMilli,
          2500,
        );
        expect((await _balance(database, 'damaged-location')).onHandMilli, 200);
      },
    );

    test(
      'duplicate receipt operation does not add destination stock twice',
      () async {
        var transfer = await _createTransfer(repository, quantity: 1000);
        await repository.submit(
          context: _sourceContext,
          transferId: transfer.id,
          expectedVersion: transfer.version,
          operationId: 'submit-idempotent',
        );
        transfer = (await repository.getTransfer(
          context: _sourceContext,
          transferId: transfer.id,
        ))!;
        await repository.ship(
          context: _sourceContext,
          transferId: transfer.id,
          expectedVersion: transfer.version,
          operationId: 'ship-idempotent',
        );
        transfer = (await repository.getTransfer(
          context: _destinationContext,
          transferId: transfer.id,
        ))!;
        final draft = TransferReceiptDraft(
          operationId: 'receive-idempotent',
          lines: [
            TransferReceiptLineDraft(
              transferItemId: transfer.lines.single.id,
              receivedQuantityMilli: 1000,
              damagedQuantityMilli: 0,
            ),
          ],
        );

        final first = await repository.receive(
          context: _destinationContext,
          transferId: transfer.id,
          expectedVersion: transfer.version,
          draft: draft,
        );
        final retry = await repository.receive(
          context: _destinationContext,
          transferId: transfer.id,
          expectedVersion: transfer.version,
          draft: draft,
        );

        expect(first.isSuccess, isTrue);
        expect(retry.isSuccess, isTrue);
        expect(
          (await _balance(database, 'destination-location')).onHandMilli,
          1000,
        );
        expect(
          (await database.select(database.inventoryTransactions).get()).where(
            (row) => row.transactionType == 'transfer_receipt',
          ),
          hasLength(1),
        );
      },
    );

    test(
      'users cannot approve outside assigned destination branches',
      () async {
        final workflow = TransferWorkflowUseCase(
          repository: repository,
          requirePermission: const RequirePermissionUseCase(),
        );
        final result = await workflow.approve(
          session: _sourceOnlySession,
          transfer: _domainTransfer(status: StockTransferStatus.submitted),
        );

        expect(result.failureOrNull, isA<AuthorizationFailure>());
        expect(await database.select(database.transferEvents).get(), isEmpty);
      },
    );

    test(
      'organization-wide remote transfer changes converge locally',
      () async {
        final occurredAt = DateTime.utc(2026, 8, 31, 9);
        await OperationsChangeApplier(database).apply(
          RemoteChangeEnvelope(
            change: RemoteChange(
              sequence: 10,
              organizationId: 'organization',
              branchId: null,
              aggregateType: 'stock_transfer',
              aggregateId: 'remote-transfer',
              operationId: 'remote-receipt',
              changeType: 'upsert',
              version: 4,
              payload: const {},
              occurredAt: occurredAt,
            ),
            commandType: 'transfer.receive',
            actorUserId: 'user',
            commandPayload: const {'id': 'remote-transfer'},
            result: {
              'transfer': {
                'id': 'remote-transfer',
                'sourceBranchId': 'source',
                'destinationBranchId': 'destination',
                'transferNumber': 'TR-SRC-REMOTE',
                'status': 'received',
                'approvalRequired': false,
                'createdByUserId': 'user',
                'version': 4,
                'createdAt': occurredAt.toIso8601String(),
                'updatedAt': occurredAt.toIso8601String(),
                'receivedAt': occurredAt.toIso8601String(),
              },
              'items': const [
                {
                  'id': 'remote-item',
                  'productId': 'product',
                  'sourceStockLocationId': 'source-location',
                  'destinationStockLocationId': 'destination-location',
                  'requestedQuantityMilli': 1000,
                  'shippedQuantityMilli': 1000,
                  'receivedQuantityMilli': 1000,
                  'damagedQuantityMilli': 0,
                  'discrepancyQuantityMilli': 0,
                  'version': 2,
                },
              ],
              'event': {
                'id': 'remote-event',
                'eventType': 'received',
                'fromStatus': 'shipped',
                'toStatus': 'received',
                'actorUserId': 'user',
                'metadata': const <String, Object?>{},
                'occurredAt': occurredAt.toIso8601String(),
              },
              'inventory': {
                'inventoryTransaction': {
                  'id': 'remote-receipt-inventory',
                  'transactionType': 'transfer_receipt',
                  'status': 'posted',
                  'occurredAt': occurredAt.toIso8601String(),
                },
                'lines': const [
                  {
                    'stockLocationId': 'destination-location',
                    'productId': 'product',
                    'quantityDeltaMilli': 1000,
                  },
                ],
                'balances': const [
                  {
                    'id': 'destination-location-balance',
                    'stockLocationId': 'destination-location',
                    'productId': 'product',
                    'onHandMilli': 1000,
                    'reservedMilli': 0,
                    'version': 1,
                  },
                ],
              },
            },
          ),
        );

        final transfer = await repository.getTransfer(
          context: _destinationContext,
          transferId: 'remote-transfer',
        );
        expect(transfer?.status, StockTransferStatus.received);
        expect(transfer?.events.single.eventType, 'received');
        expect(
          (await _balance(database, 'destination-location')).onHandMilli,
          1000,
        );
        expect(
          await database.select(database.inventoryLedgerEntries).get(),
          hasLength(1),
        );
      },
    );
  });
}

const _sourceContext = BusinessContext(
  organizationId: 'organization',
  branchId: 'source',
  actorUserId: 'user',
);
const _destinationContext = BusinessContext(
  organizationId: 'organization',
  branchId: 'destination',
  actorUserId: 'user',
);

DriftTransfersRepository _repository(AppDatabase database) {
  return DriftTransfersRepository(
    database: database,
    localDataSource: TransfersLocalDataSource(database),
    localMutationTransaction: LocalMutationTransaction(database),
    idGenerator: _SequenceIdGenerator(),
    clock: FixedAppClock(DateTime.utc(2026, 8, 31, 8)),
  );
}

Future<StockTransfer> _createTransfer(
  DriftTransfersRepository repository, {
  required int quantity,
}) async {
  final result = await repository.createDraft(
    context: _sourceContext,
    draft: StockTransferDraft(
      destinationBranchId: 'destination',
      operationId: 'create-$quantity',
      lines: [
        StockTransferLineDraft(
          productId: 'product',
          sourceStockLocationId: 'source-location',
          destinationStockLocationId: 'destination-location',
          quantityMilli: quantity,
        ),
      ],
    ),
  );
  expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
  return (await repository.getTransfer(
    context: _sourceContext,
    transferId: result.valueOrNull!,
  ))!;
}

Future<InventoryBalance> _balance(AppDatabase database, String locationId) {
  return (database.select(
    database.inventoryBalances,
  )..where((row) => row.stockLocationId.equals(locationId))).getSingle();
}

Future<void> _seed(AppDatabase database) async {
  final now = DateTime.utc(2026, 8, 31);
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
  for (final branch in const [
    ('source', 'SRC', 'Source Branch'),
    ('destination', 'DST', 'Destination Branch'),
  ]) {
    await database
        .into(database.branches)
        .insert(
          BranchesCompanion.insert(
            id: branch.$1,
            organizationId: 'organization',
            code: branch.$2,
            name: branch.$3,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
  await database
      .into(database.appUsers)
      .insert(
        AppUsersCompanion.insert(
          id: 'user',
          organizationId: 'organization',
          email: 'user@jce.test',
          displayName: 'Transfer User',
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.units)
      .insert(
        UnitsCompanion.insert(
          id: 'unit',
          organizationId: 'organization',
          code: 'PC',
          name: 'Piece',
          abbreviation: 'pc',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.products)
      .insert(
        ProductsCompanion.insert(
          id: 'product',
          organizationId: 'organization',
          unitId: 'unit',
          sku: 'SKU-1',
          normalizedSku: 'sku1',
          name: 'Transfer Product',
          normalizedName: 'transferproduct',
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (final location in const [
    ('source-location', 'source', 'SRC-WH', 'Source Warehouse', 'warehouse'),
    (
      'destination-location',
      'destination',
      'DST-WH',
      'Destination Warehouse',
      'warehouse',
    ),
    ('damaged-location', 'destination', 'DST-DMG', 'Damaged', 'damaged'),
  ]) {
    await database
        .into(database.stockLocations)
        .insert(
          StockLocationsCompanion.insert(
            id: location.$1,
            organizationId: 'organization',
            branchId: location.$2,
            code: location.$3,
            name: location.$4,
            locationType: Value(location.$5),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
  await database
      .into(database.inventoryBalances)
      .insert(
        InventoryBalancesCompanion.insert(
          id: 'source-balance',
          organizationId: 'organization',
          branchId: 'source',
          stockLocationId: 'source-location',
          productId: 'product',
          onHandMilli: const Value(10000),
          updatedAt: now,
        ),
      );
  for (final locationId in const ['destination-location', 'damaged-location']) {
    await database
        .into(database.inventoryBalances)
        .insert(
          InventoryBalancesCompanion.insert(
            id: '$locationId-balance',
            organizationId: 'organization',
            branchId: 'destination',
            stockLocationId: locationId,
            productId: 'product',
            updatedAt: now,
          ),
        );
  }
}

AuthSession get _sourceOnlySession {
  const role = AccessRole(
    id: 'manager',
    code: 'manager',
    name: 'Manager',
    permissions: {
      AppPermission.manageInventory,
      AppPermission.approveTransfers,
    },
  );
  return const AuthSession(
    activeOrganizationId: 'organization',
    activeBranchId: 'source',
    user: AppUser(
      firebaseUid: 'firebase-user',
      email: 'user@jce.test',
      displayName: 'Transfer User',
      organizations: [
        OrganizationAccess(
          appUserId: 'user',
          organization: Organization(
            id: 'organization',
            code: 'JCE',
            name: 'JCE',
            timezone: 'Asia/Manila',
          ),
          status: UserAccountStatus.active,
          organizationRoles: [],
          branches: [
            BranchAccess(
              branch: Branch(
                id: 'source',
                organizationId: 'organization',
                code: 'SRC',
                name: 'Source Branch',
                timezone: 'Asia/Manila',
              ),
              roles: [role],
            ),
          ],
        ),
      ],
    ),
  );
}

StockTransfer _domainTransfer({required StockTransferStatus status}) {
  final now = DateTime.utc(2026, 8, 31);
  return StockTransfer(
    id: 'transfer',
    transferNumber: 'TR-SRC-1',
    sourceBranchId: 'source',
    sourceBranchName: 'Source Branch',
    destinationBranchId: 'destination',
    destinationBranchName: 'Destination Branch',
    status: status,
    approvalRequired: true,
    createdByUserId: 'user',
    version: 1,
    createdAt: now,
    updatedAt: now,
    lines: const [],
    events: const [],
  );
}

class _SequenceIdGenerator implements IdGenerator {
  var _value = 0;

  @override
  String newId() => 'phase10-${(_value++).toString().padLeft(8, '0')}';
}
