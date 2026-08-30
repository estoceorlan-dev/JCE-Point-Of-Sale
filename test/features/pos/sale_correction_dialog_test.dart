import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/pos/domain/entities/payment.dart';
import 'package:jce_pos/features/pos/domain/entities/sale.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_correction.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_status.dart';
import 'package:jce_pos/features/pos/presentation/providers/pos_providers.dart';
import 'package:jce_pos/features/pos/presentation/widgets/sale_correction_dialog.dart';

void main() {
  testWidgets('return form exposes quantity, disposition, reason, and refund', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          returnDestinationsProvider.overrideWith(
            (ref) async => const [
              ReturnDestination(
                stockLocationId: 'returns',
                name: 'Returns',
                locationType: 'returns',
                isDefault: false,
              ),
              ReturnDestination(
                stockLocationId: 'damaged',
                name: 'Damaged',
                locationType: 'damaged',
                isDefault: false,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SaleCorrectionDialog(
              sale: _sale,
              type: SaleCorrectionType.saleReturn,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Return items from MAIN-0001'), findsOneWidget);
    expect(find.textContaining('Returnable 0.75 Piece'), findsOneWidget);
    expect(find.text('Reason code'), findsOneWidget);
    expect(find.text('Refund method'), findsOneWidget);
    expect(find.text('Return'), findsOneWidget);
  });
}

final _sale = SaleRecord(
  id: 'sale',
  branchId: 'branch',
  registerId: 'register',
  registerName: 'Front',
  receiptNumber: 'MAIN-0001',
  status: SaleStatus.partiallyReturned,
  cashierUserId: 'cashier',
  subtotalMinor: 10000,
  discountMinor: 0,
  taxMinor: 0,
  totalMinor: 10000,
  tenderedMinor: 10000,
  changeMinor: 0,
  completedAt: DateTime.utc(2026, 8, 29),
  items: const [
    SaleItem(
      id: 'item',
      productId: 'product',
      stockLocationId: 'returns',
      lineNumber: 1,
      productName: 'Product',
      sku: 'SKU-1',
      unitName: 'Piece',
      quantityMilli: 1000,
      returnedQuantityMilli: 250,
      unitPriceMinor: 10000,
      unitCostMinor: 0,
      taxRateBasisPoints: 0,
      taxInclusive: true,
      grossAmountMinor: 10000,
      discountAmountMinor: 0,
      netAmountMinor: 10000,
      taxAmountMinor: 0,
      totalAmountMinor: 10000,
    ),
  ],
  payments: const [
    SalePayment(
      id: 'payment',
      method: SalePaymentMethod.cash,
      tenderedAmountMinor: 10000,
      appliedAmountMinor: 10000,
      changeAmountMinor: 0,
    ),
  ],
);
