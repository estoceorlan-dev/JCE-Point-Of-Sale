import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/cart.dart';
import '../../domain/entities/sale_product.dart';
import '../../domain/value_objects/cart_pricing.dart';

final cartControllerProvider = NotifierProvider<CartController, Cart>(
  CartController.new,
);

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
  @override
  Cart build() => const Cart();

  Result<void, Failure> addProduct(SaleProduct product) {
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
      state = state.copyWith(
        lines: [
          ...state.lines,
          CartLine(product: product, quantityMilli: 1000),
        ],
      );
      return const Result.success(null);
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
    );
    state = state.copyWith(lines: lines);
    return const Result.success(null);
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
    lines[index] = lines[index].copyWith(quantityMilli: quantityMilli);
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

  void removeProduct(String productId) {
    state = state.copyWith(
      lines: state.lines
          .where((line) => line.product.id != productId)
          .toList(growable: false),
    );
    if (state.lines.isEmpty) clear();
  }

  void clear() => state = const Cart();

  Result<void, Failure> _commit(Cart next) {
    try {
      CartPricingCalculator.calculate(next);
      state = next;
      return const Result.success(null);
    } on Failure catch (failure) {
      return Result.failure(failure);
    }
  }
}
