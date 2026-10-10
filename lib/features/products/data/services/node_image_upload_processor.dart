import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/remote/remote_api_exception.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../shared/models/business_context.dart';
import '../../../auth/data/repositories/native_api_session_repository.dart';
import '../../domain/services/image_upload_processor.dart';
import 'product_image_bytes_reader.dart';

class NodeImageUploadProcessor implements ImageUploadProcessor {
  NodeImageUploadProcessor(
    this.database,
    this.sessions,
    this.clock,
    this.logger,
  );
  final AppDatabase database;
  final NativeApiSessionRepository sessions;
  final AppClock clock;
  final AppLogger logger;
  Future<int>? _processing;
  @override
  Future<int> processPending(BusinessContext context) => _processing ??=
      _processPending(context).whenComplete(() => _processing = null);
  Future<int> _processPending(BusinessContext context) async {
    try {
      final meta = await sessions.api.request('/v1/meta', method: 'GET');
      if ((meta['capabilities'] as Map?)?['images'] != true) return 0;
      final stale = clock.nowUtc().subtract(const Duration(minutes: 5));
      await (database.update(database.productImages)..where(
            (row) =>
                row.organizationId.equals(context.organizationId) &
                row.uploadStatus.equals('uploading') &
                row.updatedAt.isSmallerThanValue(stale),
          ))
          .write(const ProductImagesCompanion(uploadStatus: Value('failed')));
      final pending =
          await (database.select(database.productImages)
                ..where(
                  (row) =>
                      row.organizationId.equals(context.organizationId) &
                      row.deletedAt.isNull() &
                      row.localPath.isNotNull() &
                      row.uploadStatus.isIn(['pending', 'failed']),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.updatedAt)])
                ..limit(20))
              .get();
      var uploaded = 0;
      for (final image in pending) {
        final key = 'node.image.retry.${image.id}';
        final previous =
            jsonDecode(await database.metadataDao.readValue(key) ?? '{}')
                as Map;
        final next = DateTime.tryParse(previous['next'] as String? ?? '');
        if (next != null && next.isAfter(clock.nowUtc())) continue;
        final productPending =
            await (database.select(database.syncOutboxEntries)
                  ..where(
                    (row) =>
                        row.organizationId.equals(context.organizationId) &
                        row.aggregateId.equals(image.productId) &
                        row.commandType.equals('product.create') &
                        row.status.equals('succeeded').not(),
                  )
                  ..limit(1))
                .get();
        if (productPending.isNotEmpty) continue;
        await (database.update(
          database.productImages,
        )..where((row) => row.id.equals(image.id))).write(
          ProductImagesCompanion(
            uploadStatus: const Value('uploading'),
            updatedAt: Value(clock.nowUtc()),
          ),
        );
        try {
          final bytes = await readProductImageBytes(image.localPath!);
          if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
            throw const FormatException('Images must be at most 5 MiB.');
          }
          final checksum = sha256.convert(bytes).toString();
          final digestKey = 'node.image.digest.${image.id}';
          final original = await database.metadataDao.readValue(digestKey);
          if (original != null && original != checksum) {
            throw const FormatException(
              'The queued file changed. Add it with a new image ID.',
            );
          }
          await database.metadataDao.writeValue(
            key: digestKey,
            value: checksum,
            updatedAt: clock.nowUtc(),
          );
          final response = await sessions.authenticated(
            '/v1/products/${image.productId}/images/${image.id}',
            method: 'PUT',
            syncRequest: true,
            body: {
              'branchId': context.branchId,
              'bytesBase64': base64Encode(bytes),
              'sha256': checksum,
              'contentType': _type(image.localPath!),
            },
          );
          final value = response['productImage'] as Map;
          if (value['id'] != image.id ||
              value['product_id'] != image.productId ||
              value['sha256'] != checksum) {
            throw const FormatException('Image receipt mismatch.');
          }
          await (database.update(
            database.productImages,
          )..where((row) => row.id.equals(image.id))).write(
            ProductImagesCompanion(
              uploadStatus: const Value('uploaded'),
              remoteUrl: Value(value['remote_url'] as String),
              updatedAt: Value(clock.nowUtc()),
            ),
          );
          await database.metadataDao.writeValue(
            key: key,
            value: '{}',
            updatedAt: clock.nowUtc(),
          );
          uploaded++;
        } catch (error, stack) {
          final attempt = (previous['attempt'] as int? ?? 0) + 1;
          final seconds = error is RemoteApiException && error.details is Map
              ? (error.details as Map)['retryAfterSeconds'] as int?
              : null;
          final delay =
              seconds ?? (30 * (1 << attempt.clamp(0, 7))).clamp(30, 3600);
          await database.metadataDao.writeValue(
            key: key,
            value: jsonEncode({
              'attempt': attempt,
              'next': clock
                  .nowUtc()
                  .add(Duration(seconds: delay))
                  .toIso8601String(),
            }),
            updatedAt: clock.nowUtc(),
          );
          await (database.update(
            database.productImages,
          )..where((row) => row.id.equals(image.id))).write(
            ProductImagesCompanion(
              uploadStatus: const Value('failed'),
              updatedAt: Value(clock.nowUtc()),
            ),
          );
          logger.warning(
            'Optional image upload will retry; the product remains usable.',
            scope: 'images',
            error: error,
            stackTrace: stack,
          );
          if (error is RemoteApiException && error.status == 429) break;
        }
      }
      return uploaded;
    } catch (error, stack) {
      logger.warning(
        'Optional image service is unavailable; local work remains saved.',
        scope: 'images',
        error: error,
        stackTrace: stack,
      );
      return 0;
    }
  }
}

String _type(String path) {
  final value = path.toLowerCase();
  if (value.endsWith('.png')) return 'image/png';
  if (value.endsWith('.webp')) return 'image/webp';
  if (value.endsWith('.jpg') || value.endsWith('.jpeg')) return 'image/jpeg';
  throw const FormatException('Use JPEG, PNG or WebP images.');
}
