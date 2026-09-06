import '../../../../shared/models/business_context.dart';
import '../entities/cart.dart';
import '../entities/held_cart.dart';

abstract class PosCartRepository {
  Future<Cart> loadActive({
    required BusinessContext context,
    required String deviceId,
  });

  Future<void> saveActive({
    required BusinessContext context,
    required String deviceId,
    required Cart cart,
  });

  Stream<List<HeldCart>> watchHeld({
    required BusinessContext context,
    required String deviceId,
  });

  Future<String?> holdActive({
    required BusinessContext context,
    required String deviceId,
    required Cart cart,
    required String title,
  });

  Future<Cart?> resume({
    required BusinessContext context,
    required String deviceId,
    required String heldCartId,
  });

  Future<void> deleteHeld({
    required BusinessContext context,
    required String deviceId,
    required String heldCartId,
  });
}
