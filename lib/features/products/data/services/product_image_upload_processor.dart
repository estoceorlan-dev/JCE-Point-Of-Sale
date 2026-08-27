import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/business_context.dart';
import 'product_image_bytes_reader.dart';

class ProductImageUploadProcessor {
  const ProductImageUploadProcessor({
    required AppDatabase database,
    required FirebaseAuth firebaseAuth,
    required FirebaseStorage storage,
    required FirebaseFunctions functions,
    required String functionName,
    required IdGenerator idGenerator,
    required AppClock clock,
    required AppLogger logger,
  }) : _database = database,
       _firebaseAuth = firebaseAuth,
       _storage = storage,
       _functions = functions,
       _functionName = functionName,
       _idGenerator = idGenerator,
       _clock = clock,
       _logger = logger;

  final AppDatabase _database;
  final FirebaseAuth _firebaseAuth;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final String _functionName;
  final IdGenerator _idGenerator;
  final AppClock _clock;
  final AppLogger _logger;

  Future<int> processPending(BusinessContext context) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return 0;
    }
    final pending =
        await (_database.select(_database.productImages)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.deletedAt.isNull() &
                    row.localPath.isNotNull() &
                    row.uploadStatus.isIn(const ['pending', 'failed']),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.updatedAt),
                (row) => OrderingTerm.asc(row.sortOrder),
              ]))
            .get();
    var completed = 0;
    for (final image in pending) {
      if (await _uploadOne(context, user.uid, image)) {
        completed += 1;
      }
    }
    return completed;
  }

  Future<bool> _uploadOne(
    BusinessContext context,
    String firebaseUid,
    ProductImage image,
  ) async {
    final localPath = image.localPath;
    if (localPath == null) {
      return false;
    }
    final now = _clock.nowUtc();
    await (_database.update(
      _database.productImages,
    )..where((row) => row.id.equals(image.id))).write(
      ProductImagesCompanion(
        uploadStatus: const Value('uploading'),
        updatedAt: Value(now),
      ),
    );
    final stagingPath = 'users/$firebaseUid/product-images/${image.id}';
    try {
      final bytes = await readProductImageBytes(localPath);
      await _storage
          .ref(stagingPath)
          .putData(
            bytes,
            SettableMetadata(contentType: _contentType(localPath)),
          );
      final response = await _functions
          .httpsCallable(_functionName)
          .call<Map<Object?, Object?>>({
            'operationId': 'product-image:${image.id}',
            'organizationId': context.organizationId,
            'branchId': context.branchId,
            'productId': image.productId,
            'imageId': image.id,
            'stagingPath': stagingPath,
          });
      final productImage = _map(response.data['productImage']);
      final remoteUrl = productImage['remote_url'] ?? productImage['remoteUrl'];
      if (remoteUrl is! String || remoteUrl.isEmpty) {
        throw const FormatException(
          'The image finalization response did not contain a remote URL.',
        );
      }
      await _database.transaction(() async {
        await (_database.update(
          _database.productImages,
        )..where((row) => row.id.equals(image.id))).write(
          ProductImagesCompanion(
            remoteUrl: Value(remoteUrl),
            uploadStatus: const Value('uploaded'),
            updatedAt: Value(_clock.nowUtc()),
          ),
        );
        await _database
            .into(_database.localAuditLogs)
            .insert(
              LocalAuditLogsCompanion.insert(
                id: _idGenerator.newId(),
                operationId: Value('product-image:${image.id}'),
                organizationId: Value(context.organizationId),
                actorUserId: context.actorUserId,
                branchId: Value(context.branchId),
                actionType: 'sync',
                auditedEntityName: 'product_image',
                entityId: image.id,
                metadataJson: Value(
                  jsonEncode({
                    'productId': image.productId,
                    'uploadStatus': 'uploaded',
                  }),
                ),
                createdAt: _clock.nowUtc(),
              ),
            );
      });
      return true;
    } catch (error, stackTrace) {
      await (_database.update(
        _database.productImages,
      )..where((row) => row.id.equals(image.id))).write(
        ProductImagesCompanion(
          uploadStatus: const Value('failed'),
          updatedAt: Value(_clock.nowUtc()),
        ),
      );
      _logger.warning(
        'A pending product image upload failed and will be retried.',
        scope: 'product_image_upload',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}

Map<Object?, Object?> _map(Object? value) {
  if (value is Map<Object?, Object?>) {
    return value;
  }
  throw const FormatException('The image finalization response is invalid.');
}

String _contentType(String path) {
  final normalized = path.toLowerCase();
  if (normalized.endsWith('.png')) return 'image/png';
  if (normalized.endsWith('.webp')) return 'image/webp';
  if (normalized.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
