import 'dart:typed_data';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';

abstract interface class ProductImageRepository {
  /// Missing or unavailable optional images resolve to a null placeholder.
  Future<Result<Uint8List?, Failure>> load(
    BusinessContext context,
    String productId,
  );
}
