import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/pos/domain/entities/cart.dart';
import 'package:jce_pos/features/pos/domain/entities/checkout_attempt.dart';
import 'package:jce_pos/features/pos/domain/entities/held_cart.dart';
import 'package:jce_pos/features/pos/domain/entities/payment.dart';
import 'package:jce_pos/features/pos/domain/entities/sale_product.dart';
import 'package:jce_pos/features/pos/domain/repositories/pos_cart_repository.dart';
import 'package:jce_pos/features/pos/presentation/controllers/cart_controller.dart';
import 'package:jce_pos/features/pos/presentation/providers/pos_providers.dart';
import 'package:jce_pos/features/shifts/presentation/providers/shift_providers.dart';
import 'package:jce_pos/shared/models/business_context.dart';
import 'package:jce_pos/shared/providers/app_providers.dart';
import 'package:jce_pos/core/error/failure.dart';
import 'package:jce_pos/core/error/result.dart';

void main() {
  final scope = StateProvider<BusinessContext>((ref) => _context('a'));
  late _CartStore store;
  late ProviderContainer container;
  setUp(() {
    store = _CartStore();
    container = ProviderContainer(
      overrides: [
        businessContextProvider.overrideWith((ref) => ref.watch(scope)),
        posCartRepositoryProvider.overrideWithValue(store),
        currentDeviceIdProvider.overrideWith((ref) => Future.value('device')),
      ],
    );
  });
  tearDown(() => container.dispose());

  test('immediate payment refresh waits for the last autosave', () async {
    final controller = container.read(cartControllerProvider.notifier);
    await controller.refresh();
    store.saveGate = Completer<void>();
    controller.addProduct(_product);
    await store.saveStarted.future;
    var finished = false;
    final refresh = controller.refresh().then((result) {
      finished = true;
      return result;
    });
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    store.saveGate!.complete();
    expect((await refresh).isSuccess, isTrue);
    expect(
      container.read(cartControllerProvider).lines.single.quantityMilli,
      1000,
    );
    expect(store.saved['a']!.lines, hasLength(1));
  });

  test(
    'failed autosave preserves the in-memory cart and blocks stale reload',
    () async {
      final controller = container.read(cartControllerProvider.notifier);
      await controller.refresh();
      store.failSave = true;
      controller.addProduct(_product);
      final result = await controller.refresh();
      expect(result.isSuccess, isFalse);
      expect(container.read(cartControllerProvider).lines, hasLength(1));
      expect(container.read(cartPersistenceFailureProvider), isNotNull);
      store.failSave = false;
      controller.setQuantity('product', 2000);
      expect((await controller.refresh()).isSuccess, isTrue);
      expect(container.read(cartPersistenceFailureProvider), isNull);
    },
  );

  test(
    'externally approved checkout locks cart mutations after restore',
    () async {
      store.saved['a'] = Cart(
        lines: const [CartLine(product: _product, quantityMilli: 1000)],
        checkoutAttempt: CheckoutAttempt(
          operationId: 'checkout-operation',
          tenders: const [
            PaymentTender(
              method: SalePaymentMethod.card,
              tenderedAmountMinor: 100,
              reference: 'APPROVED-1',
            ),
          ],
          externalPaymentApproved: true,
          attemptedAt: DateTime.utc(2026, 9, 8),
        ),
      );
      final controller = container.read(cartControllerProvider.notifier);
      await controller.refresh();

      final add = controller.addProduct(_product);
      final customer = controller.setCustomer('customer');
      final clear = controller.clear();
      final hold = await controller.hold(title: 'Unsafe hold');

      expect(add.failureOrNull?.type, FailureType.conflict);
      expect(customer.failureOrNull?.type, FailureType.conflict);
      expect(clear.failureOrNull?.type, FailureType.conflict);
      expect(hold.failureOrNull?.type, FailureType.conflict);
      expect(container.read(cartControllerProvider).lines, hasLength(1));
    },
  );

  test(
    'a delayed restore cannot leak a previous branch cart into a new scope',
    () async {
      store.saved['a'] = const Cart(
        lines: [CartLine(product: _product, quantityMilli: 1000)],
      );
      store.loadGate = Completer<void>();
      final controller = container.read(cartControllerProvider.notifier);
      await store.loadStarted.future;
      container.read(scope.notifier).state = _context('b');
      await Future<void>.delayed(Duration.zero);
      store.loadGate!.complete();
      await controller.refresh();
      expect(container.read(cartControllerProvider).isEmpty, isTrue);
    },
  );
}

BusinessContext _context(String branch) => BusinessContext(
  organizationId: 'org',
  branchId: branch,
  actorUserId: 'cashier',
);

const _product = SaleProduct(
  id: 'product',
  sku: 'SKU-1',
  name: 'Milk',
  unitName: 'Piece',
  stockLocationId: 'floor',
  stockLocationName: 'Floor',
  unitPriceMinor: 100,
  unitCostMinor: 50,
  taxRateBasisPoints: 0,
  taxInclusive: true,
  availableQuantityMilli: 10000,
  inventoryVersion: 0,
);

class _CartStore implements PosCartRepository {
  final saved = <String, Cart>{};
  Completer<void>? saveGate;
  Completer<void>? loadGate;
  final saveStarted = Completer<void>();
  final loadStarted = Completer<void>();
  bool failSave = false;
  @override
  Future<Cart> loadActive({
    required BusinessContext context,
    required String deviceId,
  }) async {
    final snapshot = saved[context.branchId] ?? const Cart();
    if (!loadStarted.isCompleted) loadStarted.complete();
    if (context.branchId == 'a' && loadGate != null) await loadGate!.future;
    return snapshot;
  }

  @override
  Future<void> saveActive({
    required BusinessContext context,
    required String deviceId,
    required Cart cart,
  }) async {
    if (!saveStarted.isCompleted) saveStarted.complete();
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Disk unavailable');
    saved[context.branchId] = cart;
  }

  @override
  Stream<List<HeldCart>> watchHeld({
    required BusinessContext context,
    required String deviceId,
  }) => Stream.value([]);
  @override
  Future<String?> holdActive({
    required BusinessContext context,
    required String deviceId,
    required Cart cart,
    required String title,
  }) async => null;
  @override
  Future<Cart?> resume({
    required BusinessContext context,
    required String deviceId,
    required String heldCartId,
  }) async => null;
  @override
  Future<void> deleteHeld({
    required BusinessContext context,
    required String deviceId,
    required String heldCartId,
  }) async {}

  @override
  Future<Result<CheckoutAttempt, Failure>> prepareCheckoutAttempt({
    required BusinessContext context,
    required String deviceId,
    required List<PaymentTender> tenders,
    required bool externalPaymentsConfirmed,
  }) async => Result.success(
    CheckoutAttempt(
      operationId: 'checkout-operation',
      tenders: tenders,
      externalPaymentApproved: externalPaymentsConfirmed,
      attemptedAt: DateTime.utc(2026, 9, 8),
    ),
  );
}
