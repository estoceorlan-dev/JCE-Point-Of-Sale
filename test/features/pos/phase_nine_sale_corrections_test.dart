import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/remote/remote_sync_data_source.dart';
import 'package:jce_pos/core/sync/operations_change_applier.dart';
import 'package:jce_pos/core/sync/remote_change_envelope.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/pos/data/data_sources/sales_local_data_source.dart';
import 'package:jce_pos/features/pos/data/repositories/drift_sales_repository.dart';
import 'package:jce_pos/features/pos/domain/entities/cart.dart';
import 'package:jce_pos/features/pos/domain/entities/payment.dart';
import 'package:jce_pos/features/pos/domain/entities/sale.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_correction.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_product.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_status.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  group('Phase 9 sale corrections', () {
    late AppDatabase database;
    late _SequenceIdGenerator ids;
    late DriftSalesRepository repository;
    late SaleRecord sale;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      await _seed(database);
      ids = _SequenceIdGenerator();
      repository = _repository(database, ids: ids);
      final checkout = await repository.checkout(
        context: _context,
        draft: _checkoutDraft('checkout-operation'),
      );
      sale = (await repository.getSale(
        context: _context,
        saleId: checkout.valueOrNull!.saleId,
      ))!;
    });

    tearDown(() => database.close());

    test(
      'returned quantity cannot exceed the remaining sold quantity',
      () async {
        final first = await repository.correctSale(
          context: _context,
          draft: _correctionDraft(
            sale: sale,
            operationId: 'return-one',
            quantityMilli: 400,
            totalMinor: 4480,
          ),
        );
        final excessive = await repository.correctSale(
          context: _context,
          draft: _correctionDraft(
            sale: sale,
            operationId: 'return-two',
            quantityMilli: 700,
            totalMinor: 7840,
          ),
        );

        expect(first.isSuccess, isTrue);
        expect(excessive.failureOrNull, isA<ValidationFailure>());
        expect(await database.select(database.saleReturns).get(), hasLength(1));
        final hydrated = await repository.getSale(
          context: _context,
          saleId: sale.id,
        );
        expect(hydrated!.items.single.returnableQuantityMilli, 600);
        expect(hydrated.status, SaleStatus.partiallyReturned);
      },
    );

    test(
      'restock and damaged returns enter their selected locations',
      () async {
        final restock = await repository.correctSale(
          context: _context,
          draft: _correctionDraft(
            sale: sale,
            operationId: 'restock-return',
            quantityMilli: 300,
            totalMinor: 3360,
            destinationId: 'returns-location',
          ),
        );
        final damaged = await repository.correctSale(
          context: _context,
          draft: _correctionDraft(
            sale: sale,
            operationId: 'damaged-return',
            quantityMilli: 200,
            totalMinor: 2240,
            disposition: ReturnDisposition.damaged,
            destinationId: 'damaged-location',
          ),
        );

        expect(restock.isSuccess, isTrue);
        expect(
          damaged.isSuccess,
          isTrue,
          reason:
              '${damaged.failureOrNull} cause=${damaged.failureOrNull?.cause}',
        );
        expect(await _balance(database, 'returns-location'), 300);
        expect(await _balance(database, 'damaged-location'), 200);
        final ledger = await database
            .select(database.inventoryLedgerEntries)
            .get();
        expect(ledger.where((row) => row.quantityDeltaMilli > 0), hasLength(2));
      },
    );

    test('non-restock returns do not change inventory', () async {
      final before = await _balance(database, 'location');
      final result = await repository.correctSale(
        context: _context,
        draft: _correctionDraft(
          sale: sale,
          operationId: 'non-restock-return',
          quantityMilli: 1000,
          totalMinor: 11200,
          disposition: ReturnDisposition.nonRestock,
          destinationId: null,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(await _balance(database, 'location'), before);
      expect(
        (await database.select(database.saleReturns).getSingle())
            .inventoryTransactionId,
        isNull,
      );
    });

    test('refund totals must reconcile and a failure is atomic', () async {
      final result = await repository.correctSale(
        context: _context,
        draft: _correctionDraft(
          sale: sale,
          operationId: 'bad-refund',
          quantityMilli: 500,
          totalMinor: 5599,
        ),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await database.select(database.saleReturns).get(), isEmpty);
      expect(await database.select(database.saleReturnItems).get(), isEmpty);
      expect(await database.select(database.refundPayments).get(), isEmpty);
      expect(
        await database.select(database.localAuditLogs).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.syncOutboxEntries).get(),
        hasLength(1),
      );
    });

    test('cash refunds create a negative drawer movement', () async {
      final result = await repository.correctSale(
        context: _context,
        draft: _correctionDraft(
          sale: sale,
          operationId: 'cash-return',
          quantityMilli: 500,
          totalMinor: 5600,
          refundMethod: RefundMethod.cash,
        ),
      );

      expect(result.isSuccess, isTrue);
      final movement = await database
          .select(database.cashMovements)
          .getSingle();
      expect(movement.amountMinor, -5600);
      expect(movement.movementType, 'cash_out');
      final refund = await database.select(database.refundPayments).getSingle();
      expect(refund.cashMovementId, movement.id);
      expect(refund.shiftId, 'shift');
    });

    test('return and void retries are idempotent', () async {
      final draft = _correctionDraft(
        sale: sale,
        operationId: 'same-return',
        quantityMilli: 1000,
        totalMinor: 11200,
        type: SaleCorrectionType.voidSale,
      );
      final first = await repository.correctSale(
        context: _context,
        draft: draft,
      );
      final retry = await repository.correctSale(
        context: _context,
        draft: draft,
      );

      expect(retry.valueOrNull?.correctionId, first.valueOrNull?.correctionId);
      expect(await database.select(database.saleReturns).get(), hasLength(1));
      expect(
        await database.select(database.saleReturnItems).get(),
        hasLength(1),
      );
      expect(await _balance(database, 'returns-location'), 1000);
      final correctionCommand =
          (await database.select(database.syncOutboxEntries).get()).singleWhere(
            (entry) => entry.commandType == 'sale.void',
          );
      expect(correctionCommand.dependsOnOperationId, 'checkout-operation');
    });

    test(
      'corrections serialize per sale and unresolved rejections block more',
      () async {
        final first = await repository.correctSale(
          context: _context,
          draft: _correctionDraft(
            sale: sale,
            operationId: 'serialized-return-one',
            quantityMilli: 300,
            totalMinor: 3360,
          ),
        );
        final second = await repository.correctSale(
          context: _context,
          draft: _correctionDraft(
            sale: sale,
            operationId: 'serialized-return-two',
            quantityMilli: 200,
            totalMinor: 2240,
          ),
        );

        expect(first.isSuccess, isTrue);
        expect(second.isSuccess, isTrue);
        final correctionCommands =
            (await database.select(database.syncOutboxEntries).get())
                .where((entry) => entry.aggregateType == 'sale_correction')
                .toList();
        expect(correctionCommands, hasLength(2));
        expect(
          correctionCommands
              .singleWhere(
                (entry) => entry.operationId == 'serialized-return-one',
              )
              .dependsOnOperationId,
          'checkout-operation',
        );
        expect(
          correctionCommands
              .singleWhere(
                (entry) => entry.operationId == 'serialized-return-two',
              )
              .dependsOnOperationId,
          'serialized-return-one',
        );

        await (database.update(database.saleReturns)
              ..where((row) => row.operationId.equals('serialized-return-one')))
            .write(const SaleReturnsCompanion(status: Value('sync_rejected')));
        final blocked = await repository.correctSale(
          context: _context,
          draft: _correctionDraft(
            sale: sale,
            operationId: 'serialized-return-three',
            quantityMilli: 100,
            totalMinor: 1120,
          ),
        );

        expect(blocked.failureOrNull, isA<ConflictFailure>());
      },
    );

    test(
      'original sale header, items, and payments remain immutable',
      () async {
        final originalHeader = await database
            .select(database.sales)
            .getSingle();
        final originalItem = await database
            .select(database.saleItems)
            .getSingle();
        final originalPayment = await database
            .select(database.payments)
            .getSingle();

        final result = await repository.correctSale(
          context: _context,
          draft: _correctionDraft(
            sale: sale,
            operationId: 'immutable-return',
            quantityMilli: 1000,
            totalMinor: 11200,
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(
          await database.select(database.sales).getSingle(),
          originalHeader,
        );
        expect(
          await database.select(database.saleItems).getSingle(),
          originalItem,
        );
        expect(
          await database.select(database.payments).getSingle(),
          originalPayment,
        );
        final hydrated = await repository.getSale(
          context: _context,
          saleId: sale.id,
        );
        expect(hydrated!.status, SaleStatus.returned);
      },
    );

    test('configured amount threshold stores approval evidence', () async {
      await (database.update(
        database.branches,
      )..where((row) => row.id.equals('branch'))).write(
        const BranchesCompanion(returnApprovalThresholdMinor: Value(1000)),
      );
      final draft = _correctionDraft(
        sale: sale,
        operationId: 'approved-return',
        quantityMilli: 1000,
        totalMinor: 11200,
      );

      final denied = await repository.correctSale(
        context: _context,
        draft: draft,
      );
      final approved = await repository.correctSale(
        context: _context,
        draft: draft,
        approvedByUserId: 'manager-user',
      );

      expect(denied.failureOrNull, isA<AuthorizationFailure>());
      expect(approved.isSuccess, isTrue);
      final request = await database
          .select(database.approvalRequests)
          .getSingle();
      final decision = await database
          .select(database.approvalDecisions)
          .getSingle();
      expect(request.status, 'approved');
      expect(request.actualAmountMinor, 11200);
      expect(decision.decidedByUserId, 'manager-user');
    });

    test('voids outside the configured window require approval', () async {
      final lateRepository = DriftSalesRepository(
        database: database,
        localDataSource: SalesLocalDataSource(database),
        localMutationTransaction: LocalMutationTransaction(database),
        idGenerator: ids,
        clock: FixedAppClock(DateTime.utc(2026, 8, 26, 9)),
      );
      final draft = _correctionDraft(
        sale: sale,
        operationId: 'late-void',
        quantityMilli: 1000,
        totalMinor: 11200,
        type: SaleCorrectionType.voidSale,
      );

      final denied = await lateRepository.correctSale(
        context: _context,
        draft: draft,
      );
      final approved = await lateRepository.correctSale(
        context: _context,
        draft: draft,
        approvedByUserId: 'manager-user',
      );

      expect(denied.failureOrNull, isA<AuthorizationFailure>());
      expect(approved.isSuccess, isTrue);
      expect(
        (await database.select(database.saleReturns).getSingle())
            .correctionType,
        'void',
      );
    });

    test(
      'a pulled correction converges on a second local projection',
      () async {
        final saleItem = sale.items.single;
        final occurredAt = DateTime.utc(2026, 8, 26, 8, 5);
        await OperationsChangeApplier(database).apply(
          RemoteChangeEnvelope(
            change: RemoteChange(
              sequence: 9,
              organizationId: 'organization',
              branchId: 'branch',
              aggregateType: 'sale_correction',
              aggregateId: 'remote-correction',
              operationId: 'remote-return-operation',
              changeType: 'upsert',
              version: 0,
              payload: const {},
              occurredAt: occurredAt,
            ),
            commandType: 'sale.return',
            actorUserId: 'cashier-user',
            commandPayload: {
              'items': [
                {
                  'lineNumber': 1,
                  'productId': 'product',
                  'quantityMilli': 250,
                  'disposition': 'restock',
                  'destinationStockLocationId': 'returns-location',
                },
              ],
            },
            result: {
              'correction': {
                'id': 'remote-correction',
                'saleId': sale.id,
                'returnNumber': 'RET-REMOTE-1',
                'correctionType': 'return',
                'status': 'completed',
                'reasonCode': 'CUSTOMER_RETURN',
                'inventoryTransactionId': 'remote-return-inventory',
                'subtotalMinor': 2800,
                'discountMinor': 0,
                'taxMinor': 300,
                'totalMinor': 2800,
                'completedAt': occurredAt.toIso8601String(),
              },
              'items': [
                {
                  'id': 'remote-return-item',
                  'lineNumber': 1,
                  'productId': 'product',
                  'quantityMilli': 250,
                  'disposition': 'restock',
                  'destinationStockLocationId': 'returns-location',
                  'subtotalMinor': 2800,
                  'discountMinor': 0,
                  'taxMinor': 300,
                  'totalMinor': 2800,
                },
              ],
              'refunds': [
                {'id': 'remote-refund', 'method': 'card', 'amountMinor': 2800},
              ],
              'inventory': {
                'inventoryTransaction': {
                  'id': 'remote-return-inventory',
                  'transactionType': 'sale_return',
                  'status': 'posted',
                  'occurredAt': occurredAt.toIso8601String(),
                },
                'balances': [
                  {
                    'id': 'remote-return-balance',
                    'stockLocationId': 'returns-location',
                    'productId': 'product',
                    'onHandMilli': 250,
                    'version': 1,
                  },
                ],
              },
            },
          ),
        );

        final hydrated = await repository.getSale(
          context: _context,
          saleId: sale.id,
        );
        expect(hydrated!.items.single.id, saleItem.id);
        expect(hydrated.items.single.returnableQuantityMilli, 750);
        expect(hydrated.status, SaleStatus.partiallyReturned);
        expect(await _balance(database, 'returns-location'), 250);
        expect(
          await database.select(database.refundPayments).get(),
          hasLength(1),
        );
      },
    );
  });
}

const _context = BusinessContext(
  organizationId: 'organization',
  branchId: 'branch',
  actorUserId: 'cashier-user',
);

DriftSalesRepository _repository(
  AppDatabase database, {
  required IdGenerator ids,
}) {
  return DriftSalesRepository(
    database: database,
    localDataSource: SalesLocalDataSource(database),
    localMutationTransaction: LocalMutationTransaction(database),
    idGenerator: ids,
    clock: FixedAppClock(DateTime.utc(2026, 8, 26, 8)),
  );
}

CheckoutDraft _checkoutDraft(String operationId) {
  return CheckoutDraft(
    operationId: operationId,
    deviceId: 'device-a',
    cart: const Cart(
      lines: [
        CartLine(
          product: SaleProduct(
            id: 'product',
            sku: 'SKU-1',
            name: 'Original Product',
            unitName: 'Piece',
            stockLocationId: 'location',
            stockLocationName: 'Sales Floor',
            unitPriceMinor: 11200,
            unitCostMinor: 5000,
            taxRateBasisPoints: 1200,
            taxInclusive: true,
            availableQuantityMilli: 10000,
            inventoryVersion: 0,
          ),
          quantityMilli: 1000,
        ),
      ],
    ),
    tenders: const [
      PaymentTender(method: SalePaymentMethod.cash, tenderedAmountMinor: 12000),
    ],
  );
}

SaleCorrectionDraft _correctionDraft({
  required SaleRecord sale,
  required String operationId,
  required int quantityMilli,
  required int totalMinor,
  SaleCorrectionType type = SaleCorrectionType.saleReturn,
  ReturnDisposition disposition = ReturnDisposition.restock,
  String? destinationId = 'returns-location',
  RefundMethod refundMethod = RefundMethod.card,
}) {
  return SaleCorrectionDraft(
    saleId: sale.id,
    type: type,
    operationId: operationId,
    reasonCode: 'CUSTOMER_RETURN',
    deviceId: 'device-a',
    lines: [
      SaleCorrectionLineDraft(
        saleItemId: sale.items.single.id,
        quantityMilli: quantityMilli,
        disposition: disposition,
        destinationStockLocationId: destinationId,
      ),
    ],
    refunds: [RefundDraft(method: refundMethod, amountMinor: totalMinor)],
  );
}

Future<int> _balance(AppDatabase database, String locationId) async {
  final row =
      await (database.select(database.inventoryBalances)
            ..where((balance) => balance.stockLocationId.equals(locationId)))
          .getSingleOrNull();
  return row?.onHandMilli ?? 0;
}

Future<void> _seed(AppDatabase database) async {
  final now = DateTime.utc(2026, 8, 25);
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
      .into(database.taxCategories)
      .insert(
        TaxCategoriesCompanion.insert(
          id: 'tax',
          organizationId: 'organization',
          code: 'VAT12',
          name: 'VAT 12%',
          rateBasisPoints: 1200,
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
          taxCategoryId: const Value('tax'),
          sku: 'SKU-1',
          normalizedSku: 'SKU1',
          name: 'Original Product',
          normalizedName: 'original product',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.productPrices)
      .insert(
        ProductPricesCompanion.insert(
          id: 'price',
          organizationId: 'organization',
          productId: 'product',
          branchId: const Value('branch'),
          branchScope: 'branch',
          unitPriceMinor: 11200,
          effectiveFrom: now,
          createdByUserId: 'cashier-user',
          createdAt: now,
        ),
      );
  for (final (id, code, name, type, isDefault) in const [
    ('location', 'FLOOR', 'Sales Floor', 'sales_floor', true),
    ('returns-location', 'RET', 'Returns', 'returns', false),
    ('damaged-location', 'DMG', 'Damaged', 'damaged', false),
  ]) {
    await database
        .into(database.stockLocations)
        .insert(
          StockLocationsCompanion.insert(
            id: id,
            organizationId: 'organization',
            branchId: 'branch',
            code: code,
            name: name,
            locationType: Value(type),
            isDefault: Value(isDefault),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
  await database
      .into(database.inventoryBalances)
      .insert(
        InventoryBalancesCompanion.insert(
          id: 'balance',
          organizationId: 'organization',
          branchId: 'branch',
          stockLocationId: 'location',
          productId: 'product',
          onHandMilli: const Value(10000),
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
          code: 'REG-A',
          name: 'Front Register',
          assignedDeviceId: const Value('device-a'),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.shifts)
      .insert(
        ShiftsCompanion.insert(
          id: 'shift',
          organizationId: 'organization',
          branchId: 'branch',
          registerId: 'register',
          deviceId: 'device-a',
          operationId: 'open-shift',
          openingCashMinor: 10000,
          openedByUserId: 'cashier-user',
          openedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

class _SequenceIdGenerator implements IdGenerator {
  var _value = 0;

  @override
  String newId() => 'phase9-id-${_value++}';
}
