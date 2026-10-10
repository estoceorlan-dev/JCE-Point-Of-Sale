import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../auth/data/repositories/native_api_session_repository.dart';
import '../../domain/repositories/product_image_repository.dart';
import '../services/product_image_bytes_reader.dart';

class LocalProductImageRepository implements ProductImageRepository {
  const LocalProductImageRepository(this.db, {this.sessions});

  final AppDatabase db;
  final NativeApiSessionRepository? sessions;
  static const _maxBytes = 5 * 1024 * 1024;

  @override
  Future<Result<Uint8List?, Failure>> load(
    BusinessContext context,
    String productId,
  ) async {
    try {
      final images =
          await (db.select(db.productImages)
                ..where(
                  (row) =>
                      row.organizationId.equals(context.organizationId) &
                      row.productId.equals(productId) &
                      row.deletedAt.isNull(),
                )
                ..limit(1))
              .get();
      if (images.isEmpty) return const Result.success(null);
      return Result.success(await _read(images.first));
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          'The optional product image could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<Uint8List?> _read(ProductImage image) async {
    if (image.localPath != null) {
      try {
        final local = await readProductImageBytes(image.localPath!);
        if (local.isNotEmpty && local.length <= _maxBytes) return local;
      } catch (_) {
        // A missing local file may still be available in authorized server storage.
      }
    }
    final remote = sessions;
    if (remote == null || image.remoteUrl != '/v1/images/${image.id}') {
      return null;
    }
    try {
      final value = await remote.authenticated(
        image.remoteUrl!,
        method: 'GET',
        syncRequest: true,
      );
      final bytes = base64Decode(value['bytesBase64'] as String);
      if (bytes.isEmpty ||
          bytes.length > _maxBytes ||
          sha256.convert(bytes).toString() != value['sha256']) {
        return null;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }
}
