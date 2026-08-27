import 'sale_product.dart';

class CartLine {
  const CartLine({
    required this.product,
    required this.quantityMilli,
    this.itemDiscountMinor = 0,
    this.discountReason,
  });

  final SaleProduct product;
  final int quantityMilli;
  final int itemDiscountMinor;
  final String? discountReason;

  CartLine copyWith({
    int? quantityMilli,
    int? itemDiscountMinor,
    String? discountReason,
    bool clearDiscountReason = false,
  }) {
    return CartLine(
      product: product,
      quantityMilli: quantityMilli ?? this.quantityMilli,
      itemDiscountMinor: itemDiscountMinor ?? this.itemDiscountMinor,
      discountReason: clearDiscountReason
          ? null
          : discountReason ?? this.discountReason,
    );
  }
}

class Cart {
  const Cart({
    this.lines = const [],
    this.saleDiscountMinor = 0,
    this.saleDiscountReason,
  });

  final List<CartLine> lines;
  final int saleDiscountMinor;
  final String? saleDiscountReason;

  bool get isEmpty => lines.isEmpty;

  Cart copyWith({
    List<CartLine>? lines,
    int? saleDiscountMinor,
    String? saleDiscountReason,
    bool clearSaleDiscountReason = false,
  }) {
    return Cart(
      lines: lines ?? this.lines,
      saleDiscountMinor: saleDiscountMinor ?? this.saleDiscountMinor,
      saleDiscountReason: clearSaleDiscountReason
          ? null
          : saleDiscountReason ?? this.saleDiscountReason,
    );
  }
}
