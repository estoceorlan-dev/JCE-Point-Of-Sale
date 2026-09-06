import 'cart.dart';

class HeldCart {
  const HeldCart({
    required this.id,
    required this.title,
    required this.cart,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final Cart cart;
  final DateTime updatedAt;

  int get itemCount => cart.lines.length;
  int get quantityMilli =>
      cart.lines.fold(0, (total, line) => total + line.quantityMilli);
}
