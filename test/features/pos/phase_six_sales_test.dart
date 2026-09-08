import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/database/models/outbox_command.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/pos/data/data_sources/sales_local_data_source.dart';
import 'package:jce_pos/features/pos/data/repositories/drift_sales_repository.dart';
import 'package:jce_pos/features/pos/domain/entities/cart.dart';
import 'package:jce_pos/features/pos/domain/entities/payment.dart';
import 'package:jce_pos/features/pos/domain/entities/sale.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_product.dart';
import 'package:jce_pos/features/pos/domain/value_objects/cart_pricing.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  group('sale calculations', () {
    test('inclusive and exclusive taxes use exact integer minor units', () {
      final inclusive = CartPricingCalculator.calculate(
        Cart(
          lines: [
            CartLine(
              product: _product(
                unitPriceMinor: 11200,
                taxRateBasisPoints: 1200,
                taxInclusive: true,
              ),
              quantityMilli: 1000,
              itemDiscountMinor: 1200,
              discountReason: 'Promotion',
            ),
          ],
        ),
      );
      final exclusive = CartPricingCalculator.calculate(
        Cart(
          lines: [
            CartLine(
              product: _product(
                unitPriceMinor: 10000,
                taxRateBasisPoints: 1200,
                taxInclusive: false,
              ),
              quantityMilli: 1000,
            ),
          ],
        ),
      );

      expect(inclusive.taxMinor, 1071);
      expect(inclusive.totalMinor, 10000);
      expect(exclusive.taxMinor, 1200);
      expect(exclusive.totalMinor, 11200);
    });

    test('sale discount allocation is deterministic and preserves cents', () {
      final pricing = CartPricingCalculator.calculate(
        Cart(
          lines: [
            CartLine(
              product: _product(id: 'a', unitPriceMinor: 1000),
              quantityMilli: 1000,
            ),
            CartLine(
              product: _product(id: 'b', unitPriceMinor: 2000),
              quantityMilli: 1000,
            ),
          ],
          saleDiscountMinor: 301,
          saleDiscountReason: 'Bundle offer',
        ),
      );

      expect(pricing.lines.map((line) => line.allocatedSaleDiscountMinor), [
        100,
        201,
      ]);
      expect(pricing.totalMinor, 2699);
    });

    test('mixed payments reconcile applied amounts and cash change', () {
      final result = PaymentCalculator.reconcile(
        totalMinor: 10000,
        tenders: const [
          PaymentTender(
            method: SalePaymentMethod.card,
            tenderedAmountMinor: 3000,
          ),
          PaymentTender(
            method: SalePaymentMethod.eWallet,
            tenderedAmountMinor: 2000,
          ),
          PaymentTender(
            method: SalePaymentMethod.cash,
            tenderedAmountMinor: 6000,
          ),
        ],
      );

      expect(result.appliedMinor, 10000);
      expect(result.tenderedMinor, 11000);
      expect(result.changeMinor, 1000);
      expect(
        result.payments
            .singleWhere((payment) => payment.method == SalePaymentMethod.cash)
            .appliedAmountMinor,
        5000,
      );
    });
  });

  group('offline sale transaction', () {
    late AppDatabase database;
    late DriftSalesRepository repository;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      await _seedCheckoutContext(database);
      repository = _repository(database);
    });

    tearDown(() => database.close());

    test('barcode lookup resolves the branch price and local stock', () async {
      final products = await repository
          .watchSaleProducts(context: _context, search: '4800-123 456')
          .first;

      expect(products, hasLength(1));
      expect(products.single.name, 'Original Product');
      expect(products.single.unitPriceMinor, 11200);
      expect(products.single.availableQuantityMilli, 10000);
    });

    test(
      'checkout commits receipt, payment, inventory, audit, and outbox',
      () async {
        final result = await repository.checkout(
          context: _context,
          draft: _checkoutDraft(operationId: 'sale-operation'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.receiptNumber, 'MAIN-REGA-00000001');
        expect(await database.select(database.sales).get(), hasLength(1));
        expect(await database.select(database.saleItems).get(), hasLength(1));
        expect(await database.select(database.payments).get(), hasLength(1));
        expect(
          (await database.select(database.inventoryBalances).getSingle())
              .onHandMilli,
          9000,
        );
        expect(
          await database.select(database.inventoryLedgerEntries).get(),
          hasLength(1),
        );
        expect(
          await database.select(database.localAuditLogs).get(),
          hasLength(1),
        );
        expect(
          await database.select(database.syncOutboxEntries).get(),
          hasLength(1),
        );
      },
    );

    test('retrying an operation id returns the original sale once', () async {
      final draft = _checkoutDraft(operationId: 'same-operation');
      final first = await repository.checkout(context: _context, draft: draft);
      final retry = await repository.checkout(context: _context, draft: draft);

      expect(retry.valueOrNull?.saleId, first.valueOrNull?.saleId);
      expect(await database.select(database.sales).get(), hasLength(1));
      expect(
        (await database.select(database.inventoryBalances).getSingle())
            .onHandMilli,
        9000,
      );
      expect(
        await database.select(database.inventoryLedgerEntries).get(),
        hasLength(1),
      );
    });

    test(
      'sale commit removes only this terminal active cart atomically',
      () async {
        final now = DateTime.utc(2026, 8, 26);
        final draft = _checkoutDraft(operationId: 'cart-checkout');
        for (final id in ['active', 'held', 'other-device']) {
          await database
              .into(database.posCarts)
              .insert(
                PosCartsCompanion.insert(
                  id: id,
                  organizationId: _context.organizationId,
                  branchId: _context.branchId,
                  deviceId: id == 'other-device'
                      ? 'other-terminal'
                      : draft.deviceId,
                  status: id == 'held' ? 'held' : 'active',
                  activeScope: Value(id),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          await database
              .into(database.posCartItems)
              .insert(
                PosCartItemsCompanion.insert(
                  id: 'item-$id',
                  cartId: id,
                  productId: 'product',
                  snapshotSku: 'SKU-1',
                  snapshotName: 'Product',
                  quantityMilli: 1000,
                  position: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
        final result = await repository.checkout(
          context: _context,
          draft: draft,
        );
        expect(result.isSuccess, isTrue);
        expect(
          (await database.select(database.posCarts).get())
              .map((row) => row.id)
              .toSet(),
          {'held', 'other-device'},
        );
        expect(
          (await database.select(database.posCartItems).get())
              .map((row) => row.cartId)
              .toSet(),
          {'held', 'other-device'},
        );
      },
    );

    test(
      'checkout optionally attributes an offline-created customer',
      () async {
        final now = DateTime.utc(2026, 8, 26, 7);
        await database
            .into(database.customers)
            .insert(
              CustomersCompanion.insert(
                id: 'customer',
                organizationId: 'organization',
                customerNumber: 'CUS-00000001',
                displayName: 'Offline Customer',
                normalizedName: 'OFFLINECUSTOMER',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await database.outboxDao.enqueue(
          OutboxCommand(
            operationId: 'customer-create-operation',
            organizationId: 'organization',
            branchId: 'branch',
            actorUserId: 'cashier-user',
            commandType: 'customer.create',
            aggregateType: 'customer',
            aggregateId: 'customer',
            payload: const {'id': 'customer'},
            createdAt: now,
          ),
        );

        final result = await repository.checkout(
          context: _context,
          draft: _checkoutDraft(
            operationId: 'customer-sale-operation',
            customerId: 'customer',
          ),
        );

        expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
        expect(
          (await database.select(database.sales).getSingle()).customerId,
          'customer',
        );
        final saleCommand =
            await (database.select(database.syncOutboxEntries)..where(
                  (row) => row.operationId.equals('customer-sale-operation'),
                ))
                .getSingle();
        expect(saleCommand.dependsOnOperationId, 'customer-create-operation');
      },
    );

    test(
      'discounts above branch policy retain manager approval evidence',
      () async {
        await (database.update(
          database.branches,
        )..where((row) => row.id.equals('branch'))).write(
          const BranchesCompanion(
            discountApprovalThresholdBasisPoints: Value(500),
          ),
        );
        final draft = _checkoutDraft(
          operationId: 'discount-operation',
          saleDiscountMinor: 1000,
          cashTenderedMinor: 11000,
        );

        final denied = await repository.checkout(
          context: _context,
          draft: draft,
        );
        final approved = await repository.checkout(
          context: _context,
          draft: draft,
          discountApprovedByUserId: 'manager-user',
        );

        expect(denied.failureOrNull, isA<AuthorizationFailure>());
        expect(approved.isSuccess, isTrue);
        expect(
          (await database.select(database.sales).getSingle())
              .discountApprovedByUserId,
          'manager-user',
        );
        final discount = await database
            .select(database.saleDiscounts)
            .getSingle();
        expect(discount.amountMinor, 1000);
        expect(discount.approvedByUserId, 'manager-user');
      },
    );

    test(
      'a late sale failure keeps the external-payment recovery attempt',
      () async {
        final now = DateTime.utc(2026, 8, 26, 7, 55);
        await database
            .into(database.posCarts)
            .insert(
              PosCartsCompanion.insert(
                id: 'active-payment-recovery',
                organizationId: _context.organizationId,
                branchId: _context.branchId,
                deviceId: 'device-a',
                status: 'active',
                activeScope: const Value('organization|branch|device-a'),
                checkoutOperationId: const Value('failed-operation'),
                checkoutTendersJson: const Value(
                  '[{"method":"card","amountMinor":11200,"reference":"APPROVED-REFERENCE"}]',
                ),
                externalPaymentApproved: const Value(true),
                checkoutAttemptedAt: Value(now),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await database.customStatement('''
CREATE TRIGGER force_sale_failure BEFORE INSERT ON sales
BEGIN SELECT RAISE(ABORT, 'forced sale failure'); END
''');

        final base = _checkoutDraft(operationId: 'failed-operation');
        final result = await repository.checkout(
          context: _context,
          draft: CheckoutDraft(
            operationId: base.operationId,
            deviceId: base.deviceId,
            cart: base.cart,
            tenders: const [
              PaymentTender(
                method: SalePaymentMethod.card,
                tenderedAmountMinor: 11200,
                reference: 'APPROVED-REFERENCE',
              ),
            ],
          ),
        );

        expect(result.isFailure, isTrue);
        expect(await database.select(database.sales).get(), isEmpty);
        expect(await database.select(database.receiptSequences).get(), isEmpty);
        expect(
          await database.select(database.inventoryLedgerEntries).get(),
          isEmpty,
        );
        expect(
          (await database.select(database.inventoryBalances).getSingle())
              .onHandMilli,
          10000,
        );
        expect(await database.select(database.localAuditLogs).get(), isEmpty);
        expect(
          await database.select(database.syncOutboxEntries).get(),
          isEmpty,
        );
        final recovery = await database.select(database.posCarts).getSingle();
        expect(recovery.checkoutOperationId, 'failed-operation');
        expect(recovery.externalPaymentApproved, isTrue);
        expect(recovery.checkoutTendersJson, contains('APPROVED-REFERENCE'));
      },
    );

    test('sale history remains unchanged after catalog edits', () async {
      final result = await repository.checkout(
        context: _context,
        draft: _checkoutDraft(operationId: 'snapshot-operation'),
      );
      await (database.update(
        database.products,
      )..where((row) => row.id.equals('product'))).write(
        const ProductsCompanion(
          name: Value('Renamed Product'),
          normalizedName: Value('renamed product'),
          sku: Value('NEW-SKU'),
          normalizedSku: Value('NEWSKU'),
        ),
      );

      final sale = await repository.getSale(
        context: _context,
        saleId: result.valueOrNull!.saleId,
      );
      expect(sale!.items.single.productName, 'Original Product');
      expect(sale.items.single.sku, 'SKU-1');
      expect(sale.items.single.unitPriceMinor, 11200);
    });

    test('completed sales survive an offline database restart', () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp('jce-phase-six-');
      final file = File('${directory.path}${Platform.pathSeparator}sales.db');
      AppDatabase? reopened;
      try {
        final persistent = AppDatabase.forTesting(NativeDatabase(file));
        await _seedCheckoutContext(persistent);
        final firstRepository = _repository(persistent);
        final result = await firstRepository.checkout(
          context: _context,
          draft: _checkoutDraft(operationId: 'persistent-operation'),
        );
        await persistent.close();

        reopened = AppDatabase.forTesting(NativeDatabase(file));
        final sale = await _repository(
          reopened,
        ).getSale(context: _context, saleId: result.valueOrNull!.saleId);

        expect(sale?.receiptNumber, 'MAIN-REGA-00000001');
        expect(sale?.items.single.productName, 'Original Product');
      } finally {
        await reopened?.close();
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    });
  });
}

const _context = BusinessContext(
  organizationId: 'organization',
  branchId: 'branch',
  actorUserId: 'cashier-user',
);

SaleProduct _product({
  String id = 'product',
  int unitPriceMinor = 10000,
  int taxRateBasisPoints = 0,
  bool taxInclusive = true,
}) {
  return SaleProduct(
    id: id,
    sku: 'SKU-$id',
    name: 'Product $id',
    unitName: 'Piece',
    stockLocationId: 'location',
    stockLocationName: 'Sales Floor',
    unitPriceMinor: unitPriceMinor,
    unitCostMinor: 0,
    taxRateBasisPoints: taxRateBasisPoints,
    taxInclusive: taxInclusive,
    availableQuantityMilli: 10000,
    inventoryVersion: 0,
  );
}

CheckoutDraft _checkoutDraft({
  required String operationId,
  int saleDiscountMinor = 0,
  int cashTenderedMinor = 12000,
  String? customerId,
}) {
  return CheckoutDraft(
    operationId: operationId,
    deviceId: 'device-a',
    customerId: customerId,
    cart: Cart(
      lines: [
        CartLine(
          product: _product(unitPriceMinor: 11200, taxRateBasisPoints: 1200),
          quantityMilli: 1000,
        ),
      ],
      saleDiscountMinor: saleDiscountMinor,
      saleDiscountReason: saleDiscountMinor == 0 ? null : 'Manager promotion',
    ),
    tenders: [
      PaymentTender(
        method: SalePaymentMethod.cash,
        tenderedAmountMinor: cashTenderedMinor,
      ),
    ],
  );
}

DriftSalesRepository _repository(AppDatabase database) {
  return DriftSalesRepository(
    database: database,
    localDataSource: SalesLocalDataSource(database),
    localMutationTransaction: LocalMutationTransaction(database),
    idGenerator: _SequenceIdGenerator(),
    clock: FixedAppClock(DateTime.utc(2026, 8, 26, 8)),
  );
}

Future<void> _seedCheckoutContext(AppDatabase database) async {
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
      .into(database.productBarcodes)
      .insert(
        ProductBarcodesCompanion.insert(
          id: 'barcode',
          organizationId: 'organization',
          productId: 'product',
          barcode: '4800123456',
          normalizedBarcode: '4800123456',
          isPrimary: const Value(true),
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
  await database
      .into(database.stockLocations)
      .insert(
        StockLocationsCompanion.insert(
          id: 'location',
          organizationId: 'organization',
          branchId: 'branch',
          code: 'FLOOR',
          name: 'Sales Floor',
          locationType: const Value('sales_floor'),
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
  String newId() => 'sale-id-${_value++}';
}
