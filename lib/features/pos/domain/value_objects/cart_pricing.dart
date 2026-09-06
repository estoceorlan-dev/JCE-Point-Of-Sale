import '../../../../core/error/failures.dart';
import '../entities/cart.dart';

class PricedCartLine {
  const PricedCartLine({
    required this.line,
    required this.grossAmountMinor,
    required this.itemDiscountMinor,
    required this.allocatedSaleDiscountMinor,
    required this.netAmountMinor,
    required this.taxAmountMinor,
    required this.totalAmountMinor,
  });

  final CartLine line;
  final int grossAmountMinor;
  final int itemDiscountMinor;
  final int allocatedSaleDiscountMinor;
  final int netAmountMinor;
  final int taxAmountMinor;
  final int totalAmountMinor;

  int get discountAmountMinor => itemDiscountMinor + allocatedSaleDiscountMinor;
}

class CartPricing {
  const CartPricing({
    required this.lines,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
  });

  final List<PricedCartLine> lines;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;

  int get discountBasisPoints =>
      subtotalMinor == 0 ? 0 : (discountMinor * 10000) ~/ subtotalMinor;
}

abstract final class CartPricingCalculator {
  static CartPricing calculate(Cart cart) {
    if (cart.lines.isEmpty) {
      throw const ValidationFailure('Add at least one product to the cart.');
    }
    if (cart.saleDiscountMinor < 0) {
      throw const ValidationFailure('Sale discount cannot be negative.');
    }
    final grossAmounts = <int>[];
    final discountBases = <int>[];
    var subtotal = 0;
    var itemDiscountTotal = 0;
    for (final line in cart.lines) {
      if (line.validationMessage case final message?) {
        throw ValidationFailure(message);
      }
      if (line.quantityMilli <= 0) {
        throw const ValidationFailure(
          'Cart quantities must be greater than zero.',
        );
      }
      if (line.itemDiscountMinor < 0) {
        throw const ValidationFailure('Item discounts cannot be negative.');
      }
      final gross = _roundDivide(
        line.product.unitPriceMinor * line.quantityMilli,
        1000,
      );
      if (line.itemDiscountMinor > gross) {
        throw ValidationFailure(
          'The discount for ${line.product.name} exceeds its line amount.',
        );
      }
      if (line.itemDiscountMinor > 0 &&
          (line.discountReason?.trim().isEmpty ?? true)) {
        throw ValidationFailure(
          'Enter a discount reason for ${line.product.name}.',
        );
      }
      grossAmounts.add(gross);
      discountBases.add(gross - line.itemDiscountMinor);
      subtotal += gross;
      itemDiscountTotal += line.itemDiscountMinor;
    }
    final saleDiscountBase = subtotal - itemDiscountTotal;
    if (cart.saleDiscountMinor > saleDiscountBase) {
      throw const ValidationFailure(
        'The sale discount exceeds the cart amount.',
      );
    }
    if (cart.saleDiscountMinor > 0 &&
        (cart.saleDiscountReason?.trim().isEmpty ?? true)) {
      throw const ValidationFailure('Enter a reason for the sale discount.');
    }

    final allocations = _allocate(
      cart.saleDiscountMinor,
      discountBases,
      saleDiscountBase,
    );
    final pricedLines = <PricedCartLine>[];
    var taxTotal = 0;
    var total = 0;
    for (var index = 0; index < cart.lines.length; index++) {
      final line = cart.lines[index];
      final net = discountBases[index] - allocations[index];
      final rate = line.product.taxRateBasisPoints;
      final tax = rate == 0
          ? 0
          : line.product.taxInclusive
          ? _roundDivide(net * rate, 10000 + rate)
          : _roundDivide(net * rate, 10000);
      final lineTotal = line.product.taxInclusive ? net : net + tax;
      pricedLines.add(
        PricedCartLine(
          line: line,
          grossAmountMinor: grossAmounts[index],
          itemDiscountMinor: line.itemDiscountMinor,
          allocatedSaleDiscountMinor: allocations[index],
          netAmountMinor: net,
          taxAmountMinor: tax,
          totalAmountMinor: lineTotal,
        ),
      );
      taxTotal += tax;
      total += lineTotal;
    }
    return CartPricing(
      lines: pricedLines,
      subtotalMinor: subtotal,
      discountMinor: itemDiscountTotal + cart.saleDiscountMinor,
      taxMinor: taxTotal,
      totalMinor: total,
    );
  }
}

List<int> _allocate(int amount, List<int> bases, int totalBase) {
  if (amount == 0) return List.filled(bases.length, 0);
  if (totalBase <= 0) {
    throw const ValidationFailure(
      'A discount cannot be allocated to a zero-value cart.',
    );
  }
  final result = List.filled(bases.length, 0);
  final eligible = <int>[
    for (var index = 0; index < bases.length; index++)
      if (bases[index] > 0) index,
  ];
  var allocated = 0;
  for (var position = 0; position < eligible.length; position++) {
    final index = eligible[position];
    final value = position == eligible.length - 1
        ? amount - allocated
        : (amount * bases[index]) ~/ totalBase;
    result[index] = value;
    allocated += value;
  }
  return result;
}

int _roundDivide(int numerator, int denominator) {
  return (numerator + denominator ~/ 2) ~/ denominator;
}
