import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/native.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/pos/domain/entities/checkout_attempt.dart';
import 'package:jce_pos/features/pos/domain/entities/payment.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_product.dart';
import 'package:jce_pos/features/pos/presentation/controllers/cart_controller.dart';
import 'package:jce_pos/features/pos/presentation/pages/checkout_page.dart';
import 'package:jce_pos/features/pos/presentation/providers/pos_providers.dart';
import 'package:jce_pos/features/shifts/domain/entities/cash_shift.dart';
import 'package:jce_pos/features/shifts/presentation/providers/shift_providers.dart';

void main() {
  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());
  testWidgets('cashier can build a cart and open split payment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          saleProductSearchProvider.overrideWith(
            (ref, search) => Stream.value(const [_saleProduct]),
          ),
          saleProductBrowserProvider.overrideWith(
            (ref, query) => Stream.value(const [_saleProduct]),
          ),
          activeShiftProvider.overrideWith((ref) => Stream.value(null)),
          shiftPolicyProvider.overrideWith(
            (ref) => Future.value(
              const ShiftPolicy(
                allowMultipleOpenShiftsPerUser: false,
                allowSalesWithoutOpenShift: true,
              ),
            ),
          ),
          activePosSessionProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: Scaffold(body: CheckoutPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Products'), findsOneWidget);
    expect(find.byKey(const Key('pos-product-search')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-product-product')));
    await tester.pumpAndSettle();

    expect(find.text('Current sale'), findsOneWidget);
    expect(find.text('Original Product'), findsWidgets);
    expect(find.text('PHP 112.00'), findsWidgets);
    expect(find.byKey(const Key('checkout-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('checkout-button')));
    await tester.pumpAndSettle();

    expect(find.text('Take payment'), findsWidgets);
    expect(find.byKey(const Key('cash-payment-field')), findsOneWidget);
    expect(find.byKey(const Key('card-payment-field')), findsOneWidget);
    expect(find.byKey(const Key('wallet-payment-field')), findsOneWidget);
    expect(find.byKey(const Key('complete-sale-button')), findsOneWidget);
    await _dispose(tester);
  });
  testWidgets('approved external payment visibly locks cart edits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          saleProductBrowserProvider.overrideWith(
            (ref, query) => Stream.value(const [_saleProduct]),
          ),
          saleProductSearchProvider.overrideWith(
            (ref, search) => Stream.value(const [_saleProduct]),
          ),
          activeShiftProvider.overrideWith((ref) => Stream.value(null)),
          shiftPolicyProvider.overrideWith(
            (ref) => Future.value(
              const ShiftPolicy(
                allowMultipleOpenShiftsPerUser: false,
                allowSalesWithoutOpenShift: true,
              ),
            ),
          ),
          activePosSessionProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: Scaffold(body: CheckoutPage())),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CheckoutPage)),
    );
    final cartController = container.read(cartControllerProvider.notifier);
    cartController.addProduct(_saleProduct);
    cartController.recordCheckoutAttempt(
      CheckoutAttempt(
        operationId: 'checkout-recovery',
        tenders: const [
          PaymentTender(
            method: SalePaymentMethod.card,
            tenderedAmountMinor: 11200,
            reference: 'APPROVED-REFERENCE',
          ),
        ],
        externalPaymentApproved: true,
        attemptedAt: DateTime.utc(2026, 9, 8),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('external-payment-recovery-banner')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.pause_circle_outline),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Clear'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('checkout-button')))
          .onPressed,
      isNotNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await tester.pump();
    expect(find.text('Hold current sale'), findsNothing);
    expect(
      find.text(
        'Complete the saved payment recovery before changing this sale.',
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Clear current sale?'), findsNothing);
    await _dispose(tester);
  });
  for (final size in [
    const Size(1280, 720),
    const Size(1024, 600),
    const Size(800, 700),
    const Size(360, 640),
  ]) {
    testWidgets(
      'terminal fits ${size.width}x${size.height} and supports cart actions',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              saleProductBrowserProvider.overrideWith(
                (ref, query) => Stream.value(const [_saleProduct]),
              ),
              saleProductSearchProvider.overrideWith(
                (ref, search) => Stream.value(const [_saleProduct]),
              ),
              activeShiftProvider.overrideWith((ref) => Stream.value(null)),
              shiftPolicyProvider.overrideWith(
                (ref) => Future.value(
                  const ShiftPolicy(
                    allowMultipleOpenShiftsPerUser: false,
                    allowSalesWithoutOpenShift: true,
                  ),
                ),
              ),
              activePosSessionProvider.overrideWith((ref) => null),
            ],
            child: const MaterialApp(home: Scaffold(body: CheckoutPage())),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('add-product-product')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width < 840) {
          expect(find.byKey(const Key('pos-cart-summary')), findsOneWidget);
          await tester.tap(find.byKey(const Key('pos-cart-summary')));
          await tester.pumpAndSettle();
        }
        expect(find.text('Current sale'), findsOneWidget);
        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();
        expect(find.text('Clear current sale?'), findsOneWidget);
        await tester.tap(find.text('Keep sale'));
        await tester.pumpAndSettle();
        expect(find.text('Original Product'), findsWidgets);
        expect(tester.takeException(), isNull);
        await _dispose(tester);
      },
    );
  }
  testWidgets('F2 keeps search focused and F9 opens only one payment dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          saleProductBrowserProvider.overrideWith(
            (ref, query) => Stream.value(const [_saleProduct]),
          ),
          saleProductSearchProvider.overrideWith(
            (ref, search) => Stream.value(const [_saleProduct]),
          ),
          activeShiftProvider.overrideWith((ref) => Stream.value(null)),
          shiftPolicyProvider.overrideWith(
            (ref) => Future.value(
              const ShiftPolicy(
                allowMultipleOpenShiftsPerUser: false,
                allowSalesWithoutOpenShift: true,
              ),
            ),
          ),
          activePosSessionProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: Scaffold(body: CheckoutPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-product-product')));
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    final search = tester.widget<TextField>(
      find.byKey(const Key('pos-product-search')),
    );
    expect(search.focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complete-sale-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

const _saleProduct = SaleProduct(
  id: 'product',
  sku: 'SKU-1',
  name: 'Original Product',
  unitName: 'Piece',
  primaryBarcode: '4800123456',
  stockLocationId: 'location',
  stockLocationName: 'Sales Floor',
  unitPriceMinor: 11200,
  unitCostMinor: 0,
  taxRateBasisPoints: 1200,
  taxInclusive: true,
  availableQuantityMilli: 10000,
  inventoryVersion: 0,
);
