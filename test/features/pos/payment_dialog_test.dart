import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/error/failure.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/error/result.dart';
import 'package:jce_pos/features/pos/domain/entities/payment.dart';
import 'package:jce_pos/features/pos/domain/entities/sale.dart';
import 'package:jce_pos/features/pos/domain/value_objects/cart_pricing.dart';
import 'package:jce_pos/features/pos/presentation/controllers/checkout_controller.dart';
import 'package:jce_pos/features/pos/presentation/widgets/payment_dialog.dart';

void main() {
  testWidgets(
    'approved external payment survives failed save without automatic retry',
    (tester) async {
      final checkout = await _open(tester, requireReference: true);
      await _enter(tester, 'card', '112');
      await tester.enterText(_reference('card'), 'APPROVED-REFERENCE');
      await _confirm(tester, 'card');
      await _submit(tester);
      expect(
        find.byKey(const Key('external-payment-save-failure')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(_reference('card')).controller!.text,
        'APPROVED-REFERENCE',
      );
      expect(_isConfirmed(tester, 'card'), isTrue);
      await tester.pump(const Duration(seconds: 30));
      expect(checkout.calls, hasLength(1));
      // Editing an amount cannot erase the reconciliation warning.
      await _enter(tester, 'card', '111');
      expect(
        find.byKey(const Key('external-payment-save-failure')),
        findsOneWidget,
      );
      await _enter(tester, 'card', '112');
      await _confirm(tester, 'card');
      checkout.pending = Completer<Result<CheckoutResult, Failure>>();
      await tester.tap(find.byKey(const Key('complete-sale-button')));
      await tester.pump();
      expect(checkout.calls, hasLength(2));
      expect(checkout.calls.last.single.reference, 'APPROVED-REFERENCE');
      checkout.pending!.complete(
        const Result.success(
          CheckoutResult(saleId: 'recovered', receiptNumber: 'RECOVERED'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PaymentDialog), findsNothing);
    },
  );

  testWidgets('successful manual checkout closes payment after the save', (
    tester,
  ) async {
    final checkout = await _open(tester);
    checkout.pending = Completer<Result<CheckoutResult, Failure>>();
    await _enter(tester, 'cash', '112');
    await tester.tap(find.byKey(const Key('complete-sale-button')));
    await tester.pump();
    expect(find.byType(PaymentDialog), findsOneWidget);
    checkout.pending!.complete(
      const Result.success(
        CheckoutResult(saleId: 'test-sale', receiptNumber: 'TEST-RECEIPT'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PaymentDialog), findsNothing);
    expect(checkout.calls, hasLength(1));
  });

  testWidgets('cash is not assumed received; short cash cannot complete', (
    tester,
  ) async {
    final checkout = await _open(tester);
    expect(tester.widget<TextField>(_amount('cash')).controller!.text, isEmpty);
    await _submit(tester);
    expect(find.text('Add at least one payment.'), findsOneWidget);
    await _enter(tester, 'cash', '100');
    await _submit(tester);
    expect(
      find.text('Cash tender is less than the remaining balance.'),
      findsOneWidget,
    );
    expect(checkout.calls, isEmpty);
    await _enter(tester, 'cash', '120');
    expect(find.text('Change / excess PHP 8.00'), findsOneWidget);
    await _submit(tester);
    expect(checkout.calls.single.single.tenderedAmountMinor, 12000);
  });

  testWidgets(
    'card requires reference and cashier approval; edits invalidate approval',
    (tester) async {
      final checkout = await _open(tester, requireReference: true);
      await _enter(tester, 'card', '112');
      await _submit(tester);
      expect(find.text('Card reference is required.'), findsOneWidget);
      await tester.enterText(_reference('card'), 'TEST-REFERENCE');
      await _submit(tester);
      expect(find.textContaining('Verify the Card payment'), findsOneWidget);
      expect(checkout.calls, isEmpty);
      await _confirm(tester, 'card');
      await _enter(tester, 'card', '111');
      expect(_isConfirmed(tester, 'card'), isFalse);
      await _enter(tester, 'card', '112');
      await _confirm(tester, 'card');
      await tester.enterText(_reference('card'), 'UPDATED-REFERENCE');
      await tester.pump();
      expect(_isConfirmed(tester, 'card'), isFalse);
      await _confirm(tester, 'card');
      await _submit(tester);
      expect(checkout.calls.single.single.method, SalePaymentMethod.card);
      expect(checkout.calls.single.single.reference, 'UPDATED-REFERENCE');
    },
  );

  testWidgets(
    'split card and QR require separate confirmations and exact cash covers only balance',
    (tester) async {
      final checkout = await _open(tester);
      await _enter(tester, 'card', '30');
      await _enter(tester, 'wallet', '20');
      await tester.ensureVisible(find.text('Exact cash'));
      await tester.tap(find.text('Exact cash'));
      await tester.pump();
      expect(
        tester.widget<TextField>(_amount('cash')).controller!.text,
        '62.00',
      );
      await _confirm(tester, 'card');
      await _submit(tester);
      expect(checkout.calls, isEmpty);
      await _confirm(tester, 'wallet');
      await _submit(tester);
      final payments = checkout.calls.single;
      expect(payments.map((p) => p.tenderedAmountMinor), [6200, 3000, 2000]);
      expect(
        PaymentCalculator.reconcile(
          totalMinor: 11200,
          tenders: payments,
        ).changeMinor,
        0,
      );
    },
  );

  testWidgets(
    'QR-only exact cash clears cash and non-cash overpayment is rejected',
    (tester) async {
      final checkout = await _open(tester);
      await _enter(tester, 'wallet', '113');
      await _confirm(tester, 'wallet');
      await _submit(tester);
      expect(
        find.text('Card and e-wallet payments exceed the sale total.'),
        findsOneWidget,
      );
      expect(checkout.calls, isEmpty);
      await _enter(tester, 'cash', '112');
      await _enter(tester, 'wallet', '112');
      await tester.ensureVisible(find.text('Exact cash'));
      await tester.tap(find.text('Exact cash'));
      await tester.pump();
      expect(
        tester.widget<TextField>(_amount('cash')).controller!.text,
        isEmpty,
      );
      await _confirm(tester, 'wallet');
      await _submit(tester);
      expect(checkout.calls.single.single.method, SalePaymentMethod.eWallet);
    },
  );

  testWidgets(
    'pending checkout freezes inputs, blocks dismissal and prevents duplicate submit',
    (tester) async {
      final checkout = await _open(tester);
      checkout.pending = Completer<Result<CheckoutResult, Failure>>();
      await _enter(tester, 'cash', '112');
      await tester.tap(find.byKey(const Key('complete-sale-button')));
      await tester.pump();
      expect(tester.widget<TextField>(_amount('cash')).enabled, isFalse);
      expect(tester.widget<TextField>(_amount('card')).enabled, isFalse);
      expect(tester.widget<TextField>(_reference('wallet')).enabled, isFalse);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('complete-sale-button')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('complete-sale-button')));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(PaymentDialog), findsOneWidget);
      expect(checkout.calls, hasLength(1));
      checkout.pending!.complete(
        const Result.failure(ValidationFailure('Test save failure')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_amount('cash')).enabled, isTrue);
      expect(find.text('Test save failure'), findsOneWidget);
    },
  );

  for (final size in [const Size(1280, 720), const Size(360, 640)]) {
    testWidgets('manual payment fits $size with confirmations', (tester) async {
      await _open(tester, size: size);
      await _enter(tester, 'card', '30');
      await _enter(tester, 'wallet', '82');
      await _confirm(tester, 'card');
      await _confirm(tester, 'wallet');
      expect(tester.takeException(), isNull);
    });
  }
}

Finder _amount(String method) => find
    .descendant(
      of: find.byKey(Key('$method-payment-field')),
      matching: find.byType(TextField),
    )
    .first;

Finder _reference(String method) => find
    .descendant(
      of: find.byKey(Key('$method-payment-field')),
      matching: find.byType(TextField),
    )
    .last;

Future<void> _enter(WidgetTester tester, String method, String value) async {
  await tester.ensureVisible(_amount(method));
  await tester.enterText(_amount(method), value);
  await tester.pump();
}

Future<void> _confirm(WidgetTester tester, String method) async {
  final checkbox = find.descendant(
    of: find.byKey(Key('$method-payment-confirmation')),
    matching: find.byType(Checkbox),
  );
  await tester.ensureVisible(checkbox);
  await tester.tap(checkbox);
  await tester.pump();
}

bool _isConfirmed(WidgetTester tester, String method) => tester
    .widget<CheckboxListTile>(
      find.descendant(
        of: find.byKey(Key('$method-payment-confirmation')),
        matching: find.byType(CheckboxListTile),
      ),
    )
    .value!;

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('complete-sale-button')));
  await tester.pumpAndSettle();
}

Future<_Checkout> _open(
  WidgetTester tester, {
  bool requireReference = false,
  Size size = const Size(1280, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final checkout = _Checkout();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [checkoutControllerProvider.overrideWith(() => checkout)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => PaymentDialog(
                  pricing: const CartPricing(
                    lines: [],
                    subtotalMinor: 11200,
                    discountMinor: 0,
                    taxMinor: 0,
                    totalMinor: 11200,
                  ),
                  requiresDiscountApproval: false,
                  canApproveDiscount: false,
                  requireNonCashReference: requireReference,
                ),
              ),
              child: const Text('Pay'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Pay'));
  await tester.pumpAndSettle();
  return checkout;
}

class _Checkout extends CheckoutController {
  final calls = <List<PaymentTender>>[];
  Completer<Result<CheckoutResult, Failure>>? pending;

  @override
  Future<Result<CheckoutResult, Failure>> checkout({
    required List<PaymentTender> tenders,
    required bool approveDiscountAsManager,
  }) async {
    calls.add(tenders);
    return pending != null
        ? pending!.future
        : const Result.failure(ValidationFailure('Test save failure'));
  }
}
