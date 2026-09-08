import 'sale_product.dart';
import 'checkout_attempt.dart';

class CartLine {
  const CartLine({
    required this.product,
    required this.quantityMilli,
    this.itemDiscountMinor = 0,
    this.discountReason,
    this.validationMessage,
  });

  final SaleProduct product;
  final int quantityMilli;
  final int itemDiscountMinor;
  final String? discountReason;
  final String? validationMessage;

  CartLine copyWith({
    int? quantityMilli,
    int? itemDiscountMinor,
    String? discountReason,
    bool clearDiscountReason = false,
    String? validationMessage,
    bool clearValidationMessage = false,
  }) {
    return CartLine(
      product: product,
      quantityMilli: quantityMilli ?? this.quantityMilli,
      itemDiscountMinor: itemDiscountMinor ?? this.itemDiscountMinor,
      discountReason: clearDiscountReason
          ? null
          : discountReason ?? this.discountReason,
      validationMessage: clearValidationMessage
          ? null
          : validationMessage ?? this.validationMessage,
    );
  }
}

class Cart {
  const Cart({
    this.lines = const [],
    this.saleDiscountMinor = 0,
    this.saleDiscountReason,
    this.customerId,
    this.checkoutAttempt,
  });

  final List<CartLine> lines;
  final int saleDiscountMinor;
  final String? saleDiscountReason;
  final String? customerId;
  final CheckoutAttempt? checkoutAttempt;

  bool get isEmpty => lines.isEmpty;
  bool get hasInvalidLines =>
      lines.any((line) => line.validationMessage != null);

  Cart copyWith({
    List<CartLine>? lines,
    int? saleDiscountMinor,
    String? saleDiscountReason,
    bool clearSaleDiscountReason = false,
    String? customerId,
    bool clearCustomerId = false,
    CheckoutAttempt? checkoutAttempt,
    bool clearCheckoutAttempt = false,
  }) {
    return Cart(
      lines: lines ?? this.lines,
      saleDiscountMinor: saleDiscountMinor ?? this.saleDiscountMinor,
      saleDiscountReason: clearSaleDiscountReason
          ? null
          : saleDiscountReason ?? this.saleDiscountReason,
      customerId: clearCustomerId ? null : customerId ?? this.customerId,
      checkoutAttempt: clearCheckoutAttempt
          ? null
          : checkoutAttempt ?? this.checkoutAttempt,
    );
  }
}
