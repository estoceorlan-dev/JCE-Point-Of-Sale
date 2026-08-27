import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_product.dart';
import 'package:jce_pos/features/pos/presentation/pages/checkout_page.dart';
import 'package:jce_pos/features/pos/presentation/providers/pos_providers.dart';
import 'package:jce_pos/features/shifts/domain/entities/cash_shift.dart';
import 'package:jce_pos/features/shifts/presentation/providers/shift_providers.dart';

void main() {
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

    expect(find.text('Point of sale'), findsOneWidget);
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
  });
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
