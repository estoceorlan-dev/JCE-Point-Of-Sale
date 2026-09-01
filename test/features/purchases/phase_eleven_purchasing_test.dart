import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart'
    hide GoodsReceipt, PurchaseOrder, Supplier;
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/purchases/data/data_sources/purchases_local_data_source.dart';
import 'package:jce_pos/features/purchases/data/repositories/drift_purchases_repository.dart';
import 'package:jce_pos/features/purchases/domain/entities/goods_receipt.dart';
import 'package:jce_pos/features/purchases/domain/entities/purchase_order.dart';
import 'package:jce_pos/features/purchases/domain/entities/supplier.dart';
import 'package:jce_pos/features/purchases/domain/services/weighted_average_cost_calculator.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  group('Phase 11 purchasing and receiving', () {
    late AppDatabase database;
    late DriftPurchasesRepository repository;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      await _seed(database);
      repository = _repository(database);
    });

    tearDown(() => database.close());

    test('purchase orders never change stock before receipt', () async {
      final order = await _createApprovedOrder(repository, quantity: 5000);

      expect(order.status, PurchaseOrderStatus.approved);
      expect((await _balance(database)).onHandMilli, 10000);
      expect(
        await database.select(database.inventoryTransactions).get(),
        isEmpty,
      );
    });

    test('receipt cannot silently exceed the ordered remainder', () async {
      final order = await _createApprovedOrder(repository, quantity: 5000);

      final result = await repository.receivePurchaseOrder(
        context: _context,
        purchaseOrderId: order.id,
        expectedVersion: order.version,
        draft: GoodsReceiptDraft(
          stockLocationId: 'location',
          operationId: 'over-receipt',
          lines: [
            GoodsReceiptLineDraft(
              purchaseOrderItemId: order.lines.single.id,
              receivedQuantityMilli: 6000,
              unitCostMinor: 200,
            ),
          ],
        ),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect((await _balance(database)).onHandMilli, 10000);
      expect(await database.select(database.goodsReceipts).get(), isEmpty);
      expect(
        await database.select(database.inventoryTransactions).get(),
        isEmpty,
      );
    });

    test(
      'partial and multiple receipts close only the ordered remainder',
      () async {
        var order = await _createApprovedOrder(repository, quantity: 5000);

        final first = await _receive(
          repository,
          order,
          quantity: 2000,
          operationId: 'first-receipt',
        );
        expect(first.isSuccess, isTrue, reason: first.failureOrNull?.message);
        order = (await repository.getPurchaseOrder(
          context: _context,
          purchaseOrderId: order.id,
        ))!;
        expect(order.status, PurchaseOrderStatus.partiallyReceived);
        expect(order.lines.single.receivedQuantityMilli, 2000);
        expect(order.lines.single.remainingQuantityMilli, 3000);

        final second = await _receive(
          repository,
          order,
          quantity: 3000,
          operationId: 'second-receipt',
        );
        expect(
          second.isSuccess,
          isTrue,
          reason:
              '${second.failureOrNull?.message}: ${second.failureOrNull?.cause}',
        );
        order = (await repository.getPurchaseOrder(
          context: _context,
          purchaseOrderId: order.id,
        ))!;
        expect(order.status, PurchaseOrderStatus.received);
        expect(order.lines.single.remainingQuantityMilli, 0);
        expect(order.receipts, hasLength(2));
        expect((await _balance(database)).onHandMilli, 15000);
      },
    );

    test(
      'retrying a receipt operation creates inventory exactly once',
      () async {
        final order = await _createApprovedOrder(repository, quantity: 1000);
        final draft = GoodsReceiptDraft(
          stockLocationId: 'location',
          operationId: 'idempotent-receipt',
          lines: [
            GoodsReceiptLineDraft(
              purchaseOrderItemId: order.lines.single.id,
              receivedQuantityMilli: 1000,
              unitCostMinor: 200,
            ),
          ],
        );

        final first = await repository.receivePurchaseOrder(
          context: _context,
          purchaseOrderId: order.id,
          expectedVersion: order.version,
          draft: draft,
        );
        final retry = await repository.receivePurchaseOrder(
          context: _context,
          purchaseOrderId: order.id,
          expectedVersion: order.version,
          draft: draft,
        );

        expect(first.isSuccess, isTrue);
        expect(retry.valueOrNull, first.valueOrNull);
        expect((await _balance(database)).onHandMilli, 11000);
        expect(
          await database.select(database.goodsReceipts).get(),
          hasLength(1),
        );
        expect(
          (await database.select(database.inventoryTransactions).get()).where(
            (row) => row.transactionType == 'purchase_receipt',
          ),
          hasLength(1),
        );
      },
    );

    test(
      'cancelling a partially received order preserves received stock',
      () async {
        var order = await _createApprovedOrder(repository, quantity: 5000);
        await _receive(
          repository,
          order,
          quantity: 2000,
          operationId: 'receipt-before-cancel',
        );
        order = (await repository.getPurchaseOrder(
          context: _context,
          purchaseOrderId: order.id,
        ))!;

        final result = await repository.cancelPurchaseOrder(
          context: _context,
          purchaseOrderId: order.id,
          expectedVersion: order.version,
          reason: 'Supplier cannot fulfill the remainder',
          operationId: 'cancel-remainder',
        );

        expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
        final cancelled = (await repository.getPurchaseOrder(
          context: _context,
          purchaseOrderId: order.id,
        ))!;
        expect(cancelled.status, PurchaseOrderStatus.cancelled);
        expect(cancelled.lines.single.receivedQuantityMilli, 2000);
        expect(cancelled.lines.single.cancelledQuantityMilli, 3000);
        expect((await _balance(database)).onHandMilli, 12000);
        expect(
          await database.select(database.inventoryLedgerEntries).get(),
          hasLength(1),
        );
      },
    );

    test(
      'landed and weighted-average costs are deterministic and historical',
      () async {
        final calculator = const WeightedAverageCostCalculator();
        expect(
          calculator.landedUnitCostMinor(
            quantityMilli: 10000,
            unitCostMinor: 200,
            freightCostMinor: 1000,
            dutyCostMinor: 0,
            otherLandedCostMinor: 0,
          ),
          300,
        );
        expect(
          calculator.weightedAverageCostMinor(
            currentQuantityMilli: 10000,
            currentAverageCostMinor: 100,
            receivedQuantityMilli: 10000,
            receivedLandedUnitCostMinor: 300,
          ),
          200,
        );
        final order = await _createApprovedOrder(repository, quantity: 10000);
        final result = await repository.receivePurchaseOrder(
          context: _context,
          purchaseOrderId: order.id,
          expectedVersion: order.version,
          draft: GoodsReceiptDraft(
            stockLocationId: 'location',
            operationId: 'costed-receipt',
            lines: [
              GoodsReceiptLineDraft(
                purchaseOrderItemId: order.lines.single.id,
                receivedQuantityMilli: 10000,
                unitCostMinor: 200,
                freightCostMinor: 1000,
              ),
            ],
          ),
        );

        expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
        expect((await _balance(database)).weightedAverageCostMinor, 200);
        final receiptItem = await database
            .select(database.goodsReceiptItems)
            .getSingle();
        expect(receiptItem.unitCostMinor, 200);
        expect(receiptItem.freightCostMinor, 1000);
        expect(receiptItem.landedUnitCostMinor, 300);
        expect(receiptItem.weightedAverageCostMinorAfter, 200);
      },
    );

    test(
      'supplier and purchase outbox commands preserve dependency order',
      () async {
        final supplierId = await _createSupplier(repository);
        final created = await repository.createPurchaseOrder(
          context: _context,
          draft: PurchaseOrderDraft(
            supplierId: supplierId,
            operationId: 'dependent-order',
            lines: const [
              PurchaseOrderLineDraft(
                productId: 'product',
                orderedQuantityMilli: 1000,
                unitCostMinor: 100,
              ),
            ],
          ),
        );

        expect(created.isSuccess, isTrue);
        final command =
            await (database.select(database.syncOutboxEntries)
                  ..where((row) => row.operationId.equals('dependent-order')))
                .getSingle();
        expect(command.dependsOnOperationId, 'create-supplier');
      },
    );
  });
}

const _context = BusinessContext(
  organizationId: 'organization',
  branchId: 'branch',
  actorUserId: 'user',
);

DriftPurchasesRepository _repository(AppDatabase database) {
  return DriftPurchasesRepository(
    database: database,
    localDataSource: PurchasesLocalDataSource(database),
    localMutationTransaction: LocalMutationTransaction(database),
    idGenerator: _SequenceIdGenerator(),
    clock: FixedAppClock(DateTime.utc(2026, 8, 31, 8)),
  );
}

Future<String> _createSupplier(DriftPurchasesRepository repository) async {
  final result = await repository.createSupplier(
    context: _context,
    draft: const SupplierDraft(
      code: 'SUP-1',
      name: 'Primary Supplier',
      paymentTermsDays: 30,
      operationId: 'create-supplier',
      contacts: [
        SupplierContactDraft(
          name: 'Supplier Contact',
          email: 'orders@supplier.test',
          isPrimary: true,
        ),
      ],
    ),
  );
  expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
  return result.valueOrNull!;
}

Future<PurchaseOrder> _createApprovedOrder(
  DriftPurchasesRepository repository, {
  required int quantity,
}) async {
  final supplierId = await _createSupplier(repository);
  final created = await repository.createPurchaseOrder(
    context: _context,
    draft: PurchaseOrderDraft(
      supplierId: supplierId,
      operationId: 'create-order-$quantity',
      lines: [
        PurchaseOrderLineDraft(
          productId: 'product',
          orderedQuantityMilli: quantity,
          unitCostMinor: 200,
        ),
      ],
    ),
  );
  expect(created.isSuccess, isTrue, reason: created.failureOrNull?.message);
  var order = (await repository.getPurchaseOrder(
    context: _context,
    purchaseOrderId: created.valueOrNull!,
  ))!;
  expect(
    (await repository.submitPurchaseOrder(
      context: _context,
      purchaseOrderId: order.id,
      expectedVersion: order.version,
      operationId: 'submit-$quantity',
    )).isSuccess,
    isTrue,
  );
  order = (await repository.getPurchaseOrder(
    context: _context,
    purchaseOrderId: order.id,
  ))!;
  expect(
    (await repository.approvePurchaseOrder(
      context: _context,
      purchaseOrderId: order.id,
      expectedVersion: order.version,
      operationId: 'approve-$quantity',
    )).isSuccess,
    isTrue,
  );
  return (await repository.getPurchaseOrder(
    context: _context,
    purchaseOrderId: order.id,
  ))!;
}

Future<dynamic> _receive(
  DriftPurchasesRepository repository,
  PurchaseOrder order, {
  required int quantity,
  required String operationId,
}) => repository.receivePurchaseOrder(
  context: _context,
  purchaseOrderId: order.id,
  expectedVersion: order.version,
  draft: GoodsReceiptDraft(
    stockLocationId: 'location',
    operationId: operationId,
    lines: [
      GoodsReceiptLineDraft(
        purchaseOrderItemId: order.lines.single.id,
        receivedQuantityMilli: quantity,
        unitCostMinor: 200,
      ),
    ],
  ),
);

Future<InventoryBalance> _balance(AppDatabase database) =>
    database.select(database.inventoryBalances).getSingle();

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
          email: 'buyer@jce.test',
          displayName: 'Buyer',
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
          normalizedSku: 'SKU1',
          name: 'Purchase Product',
          normalizedName: 'PURCHASEPRODUCT',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.stockLocations)
      .insert(
        StockLocationsCompanion.insert(
          id: 'location',
          organizationId: 'organization',
          branchId: 'branch',
          code: 'WH',
          name: 'Warehouse',
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
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
          weightedAverageCostMinor: const Value(100),
          updatedAt: now,
        ),
      );
}

class _SequenceIdGenerator implements IdGenerator {
  var _value = 0;

  @override
  String newId() => 'phase11-${(_value++).toString().padLeft(8, '0')}';
}
