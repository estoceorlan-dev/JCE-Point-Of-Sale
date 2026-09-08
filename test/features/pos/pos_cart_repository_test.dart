import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/error/failure.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/pos/data/data_sources/sales_local_data_source.dart';
import 'package:jce_pos/features/pos/data/repositories/drift_pos_cart_repository.dart';
import 'package:jce_pos/features/pos/domain/entities/cart.dart';
import 'package:jce_pos/features/pos/domain/entities/payment.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_product.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  late AppDatabase database;
  late DriftPosCartRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await _seed(database);
    repository = DriftPosCartRepository(
      database: database,
      salesLocalDataSource: SalesLocalDataSource(database),
      idGenerator: _Ids(),
      clock: FixedAppClock(DateTime.utc(2026, 9, 5, 9)),
    );
  });

  tearDown(() => database.close());

  test('active cart autosave data can be restored', () async {
    await repository.saveActive(
      context: _context,
      deviceId: 'terminal-a',
      cart: const Cart(
        lines: [
          CartLine(
            product: _saleProduct,
            quantityMilli: 2000,
            itemDiscountMinor: 100,
            discountReason: 'Promotion',
          ),
        ],
        saleDiscountMinor: 50,
        saleDiscountReason: 'Loyalty',
      ),
    );

    final restored = await repository.loadActive(
      context: _context,
      deviceId: 'terminal-a',
    );

    expect(restored.lines, hasLength(1));
    expect(restored.lines.single.product.unitPriceMinor, 11200);
    expect(restored.lines.single.quantityMilli, 2000);
    expect(restored.lines.single.itemDiscountMinor, 100);
    expect(restored.saleDiscountMinor, 50);
    expect(restored.hasInvalidLines, isFalse);
  });

  test('held carts remain device-local and can be resumed', () async {
    const cart = Cart(
      lines: [CartLine(product: _saleProduct, quantityMilli: 1000)],
    );
    final heldId = await repository.holdActive(
      context: _context,
      deviceId: 'terminal-a',
      cart: cart,
      title: 'Maria',
    );

    expect(
      (await repository.loadActive(
        context: _context,
        deviceId: 'terminal-a',
      )).isEmpty,
      isTrue,
    );
    expect(
      await repository
          .watchHeld(context: _context, deviceId: 'terminal-a')
          .first,
      hasLength(1),
    );
    expect(
      await repository
          .watchHeld(context: _context, deviceId: 'terminal-b')
          .first,
      isEmpty,
    );

    final resumed = await repository.resume(
      context: _context,
      deviceId: 'terminal-a',
      heldCartId: heldId!,
    );
    expect(resumed?.lines.single.product.name, 'Original Product');
    expect(
      await repository
          .watchHeld(context: _context, deviceId: 'terminal-a')
          .first,
      isEmpty,
    );
  });

  test(
    'external checkout attempt survives restart and reuses its operation id',
    () async {
      await repository.saveActive(
        context: _context,
        deviceId: 'terminal-a',
        cart: const Cart(
          lines: [CartLine(product: _saleProduct, quantityMilli: 1000)],
        ),
      );
      const tenders = [
        PaymentTender(
          method: SalePaymentMethod.card,
          tenderedAmountMinor: 11200,
          reference: 'APPROVED-REFERENCE',
        ),
      ];
      final prepared = await repository.prepareCheckoutAttempt(
        context: _context,
        deviceId: 'terminal-a',
        tenders: tenders,
        externalPaymentsConfirmed: true,
      );

      final restored = await repository.loadActive(
        context: _context,
        deviceId: 'terminal-a',
      );
      final retry = await repository.prepareCheckoutAttempt(
        context: _context,
        deviceId: 'terminal-a',
        tenders: tenders,
        externalPaymentsConfirmed: true,
      );

      expect(
        restored.checkoutAttempt?.operationId,
        prepared.valueOrNull?.operationId,
      );
      expect(restored.checkoutAttempt?.externalPaymentApproved, isTrue);
      expect(
        restored.checkoutAttempt?.tenders.single.reference,
        'APPROVED-REFERENCE',
      );
      expect(retry.valueOrNull?.operationId, prepared.valueOrNull?.operationId);
    },
  );

  test('external checkout attempt rejects changed retry tenders', () async {
    await repository.saveActive(
      context: _context,
      deviceId: 'terminal-a',
      cart: const Cart(
        lines: [CartLine(product: _saleProduct, quantityMilli: 1000)],
      ),
    );
    await repository.prepareCheckoutAttempt(
      context: _context,
      deviceId: 'terminal-a',
      tenders: const [
        PaymentTender(
          method: SalePaymentMethod.card,
          tenderedAmountMinor: 11200,
          reference: 'APPROVED-REFERENCE',
        ),
      ],
      externalPaymentsConfirmed: true,
    );

    final changed = await repository.prepareCheckoutAttempt(
      context: _context,
      deviceId: 'terminal-a',
      tenders: const [
        PaymentTender(
          method: SalePaymentMethod.card,
          tenderedAmountMinor: 11100,
          reference: 'APPROVED-REFERENCE',
        ),
      ],
      externalPaymentsConfirmed: true,
    );

    expect(changed.failureOrNull?.type, FailureType.conflict);
    expect(changed.failureOrNull?.message, contains('do not charge again'));
  });

  test('invalid external tender cannot create a recovery lock', () async {
    await repository.saveActive(
      context: _context,
      deviceId: 'terminal-a',
      cart: const Cart(
        lines: [CartLine(product: _saleProduct, quantityMilli: 1000)],
      ),
    );

    final result = await repository.prepareCheckoutAttempt(
      context: _context,
      deviceId: 'terminal-a',
      tenders: const [
        PaymentTender(
          method: SalePaymentMethod.card,
          tenderedAmountMinor: 0,
          reference: 'INVALID',
        ),
      ],
      externalPaymentsConfirmed: true,
    );
    final restored = await repository.loadActive(
      context: _context,
      deviceId: 'terminal-a',
    );

    expect(result.failureOrNull?.type, FailureType.validation);
    expect(restored.checkoutAttempt, equals(null));
  });

  test('unknown persisted payment method fails closed', () async {
    await repository.saveActive(
      context: _context,
      deviceId: 'terminal-a',
      cart: const Cart(
        lines: [CartLine(product: _saleProduct, quantityMilli: 1000)],
      ),
    );
    await database
        .update(database.posCarts)
        .write(
          PosCartsCompanion(
            checkoutOperationId: const Value('corrupt-attempt'),
            checkoutTendersJson: const Value(
              '[{"method":"gift_card","amountMinor":11200,"reference":"X"}]',
            ),
            externalPaymentApproved: const Value(true),
            checkoutAttemptedAt: Value(DateTime.utc(2026, 9, 8)),
          ),
        );

    await expectLater(
      repository.loadActive(context: _context, deviceId: 'terminal-a'),
      throwsA(isA<FormatException>()),
    );
  });

  test('resume flags a product that became unavailable', () async {
    final heldId = await repository.holdActive(
      context: _context,
      deviceId: 'terminal-a',
      cart: const Cart(
        lines: [CartLine(product: _saleProduct, quantityMilli: 1000)],
      ),
      title: 'Unavailable test',
    );
    await (database.update(database.products)
          ..where((row) => row.id.equals('product')))
        .write(const ProductsCompanion(isActive: Value(false)));

    final resumed = await repository.resume(
      context: _context,
      deviceId: 'terminal-a',
      heldCartId: heldId!,
    );

    expect(resumed?.hasInvalidLines, isTrue);
    expect(resumed?.lines.single.validationMessage, contains('unavailable'));
  });
}

const _context = BusinessContext(
  organizationId: 'organization',
  branchId: 'branch',
  actorUserId: 'cashier',
);

const _saleProduct = SaleProduct(
  id: 'product',
  sku: 'SKU-1',
  name: 'Original Product',
  unitName: 'Piece',
  primaryBarcode: '4800123456',
  stockLocationId: 'location',
  stockLocationName: 'Sales Floor',
  unitPriceMinor: 11200,
  unitCostMinor: 8000,
  taxRateBasisPoints: 1200,
  taxInclusive: true,
  availableQuantityMilli: 10000,
  inventoryVersion: 0,
);

Future<void> _seed(AppDatabase database) async {
  final now = DateTime.utc(2026, 9, 5);
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
          createdByUserId: 'cashier',
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
}

class _Ids implements IdGenerator {
  var value = 0;

  @override
  String newId() => 'cart-id-${value++}';
}
