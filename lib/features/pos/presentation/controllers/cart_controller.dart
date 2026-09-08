import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/cart.dart';
import '../../domain/entities/checkout_attempt.dart';
import '../../domain/entities/sale_product.dart';
import '../../domain/value_objects/cart_pricing.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../shifts/presentation/providers/shift_providers.dart';
import '../providers/pos_providers.dart';

final cartControllerProvider = NotifierProvider<CartController, Cart>(
  CartController.new,
);

final cartPersistenceFailureProvider = StateProvider<Failure?>((ref) => null);

final cartPricingProvider = Provider<CartPricing?>((ref) {
  final cart = ref.watch(cartControllerProvider);
  if (cart.isEmpty) return null;
  try {
    return CartPricingCalculator.calculate(cart);
  } on Failure {
    return null;
  }
});

class CartController extends Notifier<Cart> {
  Future<void> _saveChain = Future.value();
  var _mutation = 0;
  var _scopeGeneration = 0;
  bool _disposed = false;

  @override
  Cart build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    Future.microtask(_restore);
    ref.listen(businessContextProvider, (previous, next) {
      if (previous?.organizationId != next?.organizationId ||
          previous?.branchId != next?.branchId ||
          previous?.actorUserId != next?.actorUserId) {
        _scopeGeneration++;
        _mutation++;
        state = const Cart();
        unawaited(_restore());
      }
    });
    return const Cart();
  }

  Result<void, Failure> addProduct(SaleProduct product) {
    if (_externalPaymentLock case final failure?) {
      return Result.failure(failure);
    }
    if (product.unitPriceMinor <= 0) {
      return const Result.failure(
        ValidationFailure(
          'Configure a selling price before adding this product.',
        ),
      );
    }
    final index = state.lines.indexWhere(
      (line) => line.product.id == product.id,
    );
    if (index < 0) {
      if (product.availableQuantityMilli < 1000) {
        return const Result.failure(
          ValidationFailure('There is not enough stock for this product.'),
        );
      }
      return _commit(
        state.copyWith(
          lines: [
            ...state.lines,
            CartLine(product: product, quantityMilli: 1000),
          ],
        ),
      );
    }
    final lines = [...state.lines];
    final existing = lines[index];
    if (existing.quantityMilli + 1000 > product.availableQuantityMilli) {
      return const Result.failure(
        ValidationFailure('The requested quantity exceeds available stock.'),
      );
    }
    lines[index] = existing.copyWith(
      quantityMilli: existing.quantityMilli + 1000,
      clearValidationMessage: true,
    );
    return _commit(state.copyWith(lines: lines));
  }

  Result<void, Failure> setQuantity(String productId, int quantityMilli) {
    if (quantityMilli <= 0) {
      return const Result.failure(
        ValidationFailure('Quantity must be greater than zero.'),
      );
    }
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.product.id == productId);
    if (index < 0) {
      return const Result.failure(
        ValidationFailure('Cart item was not found.'),
      );
    }
    if (quantityMilli > lines[index].product.availableQuantityMilli) {
      return const Result.failure(
        ValidationFailure('The requested quantity exceeds available stock.'),
      );
    }
    lines[index] = lines[index].copyWith(
      quantityMilli: quantityMilli,
      clearValidationMessage: true,
    );
    return _commit(state.copyWith(lines: lines));
  }

  Result<void, Failure> setItemDiscount({
    required String productId,
    required int amountMinor,
    required String reason,
  }) {
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.product.id == productId);
    if (index < 0) {
      return const Result.failure(
        ValidationFailure('Cart item was not found.'),
      );
    }
    lines[index] = lines[index].copyWith(
      itemDiscountMinor: amountMinor,
      discountReason: reason,
      clearDiscountReason: amountMinor == 0,
    );
    return _commit(state.copyWith(lines: lines));
  }

  Result<void, Failure> setSaleDiscount({
    required int amountMinor,
    required String reason,
  }) {
    return _commit(
      state.copyWith(
        saleDiscountMinor: amountMinor,
        saleDiscountReason: reason,
        clearSaleDiscountReason: amountMinor == 0,
      ),
    );
  }

  Result<void, Failure> removeProduct(String productId) {
    if (_externalPaymentLock case final failure?) {
      return Result.failure(failure);
    }
    final next = state.copyWith(
      lines: state.lines
          .where((line) => line.product.id != productId)
          .toList(growable: false),
    );
    return _commit(next.lines.isEmpty ? const Cart() : next);
  }

  Result<void, Failure> setCustomer(String? customerId) {
    return _commit(
      state.copyWith(
        customerId: customerId,
        clearCustomerId: customerId == null,
      ),
    );
  }

  Result<void, Failure> clear() => _commit(const Cart());

  void recordCheckoutAttempt(CheckoutAttempt attempt) {
    state = state.copyWith(checkoutAttempt: attempt);
  }

  void clearAfterCheckout() {
    _mutation++;
    state = const Cart();
  }

  Future<Result<String, Failure>> hold({required String title}) async {
    final context = ref.read(businessContextProvider);
    if (context == null) {
      return const Result.failure(
        AuthorizationFailure('Choose an organization and branch first.'),
      );
    }
    if (state.isEmpty) {
      return const Result.failure(ValidationFailure('The cart is empty.'));
    }
    if (_externalPaymentLock case final failure?) {
      return Result.failure(failure);
    }
    try {
      await _saveChain;
      final deviceId = await ref.read(currentDeviceIdProvider.future);
      final id = await ref
          .read(posCartRepositoryProvider)
          .holdActive(
            context: context,
            deviceId: deviceId,
            cart: state,
            title: title,
          );
      if (id == null) {
        return const Result.failure(ValidationFailure('The cart is empty.'));
      }
      _mutation++;
      state = const Cart();
      return Result.success(id);
    } catch (error, stackTrace) {
      return Result.failure(FailureMapper.fromException(error, stackTrace));
    }
  }

  Future<Result<void, Failure>> resume(String heldCartId) async {
    if (!state.isEmpty) {
      return const Result.failure(
        ValidationFailure(
          'Hold or clear the active cart before resuming another.',
        ),
      );
    }
    final context = ref.read(businessContextProvider);
    if (context == null) {
      return const Result.failure(
        AuthorizationFailure('Choose an organization and branch first.'),
      );
    }
    try {
      final deviceId = await ref.read(currentDeviceIdProvider.future);
      final cart = await ref
          .read(posCartRepositoryProvider)
          .resume(context: context, deviceId: deviceId, heldCartId: heldCartId);
      if (cart == null) {
        return const Result.failure(
          ValidationFailure('The held cart was not found.'),
        );
      }
      _mutation++;
      state = cart;
      return const Result.success(null);
    } catch (error, stackTrace) {
      return Result.failure(FailureMapper.fromException(error, stackTrace));
    }
  }

  Future<Result<void, Failure>> refresh() async {
    // Revalidation must observe every preceding autosave, including the last
    // scan immediately before F9. Never replace the cart with an older save.
    await _saveChain;
    if (_disposed) {
      return const Result.failure(DatabaseFailure('The terminal was closed.'));
    }
    final failure = ref.read(cartPersistenceFailureProvider);
    if (failure != null) return Result.failure(failure);
    return _restore();
  }

  Result<void, Failure> _commit(Cart next) {
    if (_externalPaymentLock case final failure?) {
      return Result.failure(failure);
    }
    try {
      if (!next.isEmpty) CartPricingCalculator.calculate(next);
      state = next.copyWith(clearCheckoutAttempt: true);
      _changed();
      return const Result.success(null);
    } on Failure catch (failure) {
      return Result.failure(failure);
    }
  }

  Failure? get _externalPaymentLock =>
      state.checkoutAttempt?.externalPaymentApproved == true
      ? const ConflictFailure(
          'An externally approved payment is awaiting reconciliation. '
          'Retry the saved checkout; do not change or clear this cart.',
        )
      : null;

  void _changed() {
    _mutation++;
    final snapshot = state;
    final context = ref.read(businessContextProvider);
    if (context == null) return;
    final repository = ref.read(posCartRepositoryProvider);
    final device = ref.read(currentDeviceIdProvider.future);
    final logger = ref.read(appLoggerProvider);
    final generation = _scopeGeneration;
    _saveChain = _saveChain
        .then((_) async {
          final deviceId = await device;
          await repository.saveActive(
            context: context,
            deviceId: deviceId,
            cart: snapshot,
          );
          if (!_disposed && generation == _scopeGeneration) {
            ref.read(cartPersistenceFailureProvider.notifier).state = null;
          }
        })
        .catchError((Object error, StackTrace stack) {
          logger.warning(
            'The active cart could not be saved.',
            scope: 'pos.cart',
            error: error,
            stackTrace: stack,
          );
          if (!_disposed && generation == _scopeGeneration) {
            ref.read(cartPersistenceFailureProvider.notifier).state =
                FailureMapper.fromException(error, stack);
          }
        });
  }

  Future<Result<void, Failure>> _restore() async {
    if (_disposed) return const Result.success(null);
    final context = ref.read(businessContextProvider);
    if (context == null) return const Result.success(null);
    final generation = _scopeGeneration;
    final startedAtMutation = _mutation;
    try {
      await _saveChain;
      if (_disposed || generation != _scopeGeneration) {
        return const Result.success(null);
      }
      final deviceId = await ref.read(currentDeviceIdProvider.future);
      final cart = await ref
          .read(posCartRepositoryProvider)
          .loadActive(context: context, deviceId: deviceId);
      if (!_disposed &&
          generation == _scopeGeneration &&
          startedAtMutation == _mutation) {
        state = cart;
      }
      return const Result.success(null);
    } catch (error, stack) {
      final failure = FailureMapper.fromException(error, stack);
      if (!_disposed && generation == _scopeGeneration) {
        ref.read(cartPersistenceFailureProvider.notifier).state = failure;
        ref
            .read(appLoggerProvider)
            .warning(
              'The active cart could not be restored.',
              scope: 'pos.cart',
              error: error,
              stackTrace: stack,
            );
      }
      return Result.failure(failure);
    }
  }
}
