import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/logger/app_logger.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/features/auth/data/datasources/native_auth_api.dart';
import 'package:jce_pos/features/auth/data/repositories/native_api_session_repository.dart';
import 'package:jce_pos/features/auth/data/security/credential_record_store.dart';
import 'package:jce_pos/features/auth/domain/offline/native_auth_profile.dart';
import 'package:jce_pos/features/products/data/services/node_image_upload_processor.dart';
import 'package:jce_pos/features/products/data/repositories/local_product_image_repository.dart';
import 'package:jce_pos/shared/models/business_context.dart';
import '../auth/native_auth_test_support.dart';

void main() {
  test(
    'optional images stay local offline, fall back safely and isolate organizations',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final dir = await Directory.systemTemp.createTemp('jce-image-read-');
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final bytes = [137, 80, 78, 71, 13, 10, 26, 10, 0];
      final file = File('${dir.path}/picture.png');
      await file.writeAsBytes(bytes);
      await _seed(db, DateTime.utc(2026, 10, 10), file.path);
      await db
          .update(db.productImages)
          .write(
            const ProductImagesCompanion(remoteUrl: Value('/v1/images/image')),
          );
      const context = BusinessContext(
        organizationId: 'org',
        branchId: 'branch',
        actorUserId: 'user',
      );
      expect(
        (await LocalProductImageRepository(
          db,
        ).load(context, 'product')).valueOrNull,
        bytes,
      );
      final records = CredentialRecordStore(MemoryVault(), 'deployment');
      await records.transact((state) async {
        state['session'] = {'accessToken': 'access', 'refreshToken': 'refresh'};
      });
      var requests = 0;
      var corrupt = false;
      final api = NativeAuthApi(
        MockClient((request) async {
          requests++;
          expect(request.url.path, '/v1/images/image');
          expect(request.headers['Authorization'], 'Bearer access');
          return http.Response(
            jsonEncode({
              'bytesBase64': base64Encode(bytes),
              'sha256': corrupt ? 'invalid' : sha256.convert(bytes).toString(),
            }),
            200,
          );
        }),
        NativeAuthProfile(
          deploymentId: 'deployment',
          organizationCode: 'org',
          apiOrigin: Uri.parse('https://branch.test'),
          offlineVerificationKeys: const {},
        ),
      );
      final repository = LocalProductImageRepository(
        db,
        sessions: NativeApiSessionRepository(api, records),
      );
      expect((await repository.load(context, 'product')).valueOrNull, bytes);
      expect(requests, 0);
      await file.delete();
      expect((await repository.load(context, 'product')).valueOrNull, bytes);
      expect(requests, 1);
      corrupt = true;
      final placeholder = await repository.load(context, 'product');
      expect(placeholder.isSuccess, isTrue);
      expect(placeholder.valueOrNull, isNull);
      expect(requests, 2);
      expect(
        (await repository.load(
          const BusinessContext(
            organizationId: 'other',
            branchId: 'branch',
            actorUserId: 'user',
          ),
          'product',
        )).valueOrNull,
        isNull,
      );
      expect(requests, 2);
      await db
          .update(db.productImages)
          .write(
            ProductImagesCompanion(
              deletedAt: Value(DateTime.utc(2026, 10, 11)),
            ),
          );
      expect((await repository.load(context, 'product')).valueOrNull, isNull);
      expect(requests, 2);
    },
  );

  test(
    'images wait for product acceptance and retry stable bytes independently after storage outage',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final dir = await Directory.systemTemp.createTemp('jce-image-queue-');
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final clock = _Clock(DateTime.utc(2026, 10, 10));
      final file = File('${dir.path}/picture.png');
      await file.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 0]);
      await _seed(db, clock.nowUtc(), file.path);
      final records = CredentialRecordStore(MemoryVault(), 'deployment');
      await records.transact((state) async {
        state['session'] = {'accessToken': 'access', 'refreshToken': 'refresh'};
      });
      var enabled = true, fail = true, puts = 0;
      String? digest;
      final api = NativeAuthApi(
        MockClient((request) async {
          if (request.url.path == '/v1/meta') {
            return http.Response(
              jsonEncode({
                'capabilities': {'images': enabled},
              }),
              200,
            );
          }
          puts++;
          final body = jsonDecode(request.body) as Map;
          digest ??= body['sha256'] as String;
          expect(body['sha256'], digest);
          if (fail) {
            return http.Response(
              jsonEncode({'code': 'service_unavailable'}),
              503,
            );
          }
          return http.Response(
            jsonEncode({
              'productImage': {
                'id': 'image',
                'product_id': 'product',
                'sha256': digest,
                'remote_url': '/v1/images/image',
              },
            }),
            200,
          );
        }),
        NativeAuthProfile(
          deploymentId: 'deployment',
          organizationCode: 'org',
          apiOrigin: Uri.parse('https://branch.test'),
          offlineVerificationKeys: const {},
        ),
      );
      final processor = NodeImageUploadProcessor(
        db,
        NativeApiSessionRepository(api, records),
        clock,
        const DeveloperAppLogger(),
      );
      const context = BusinessContext(
        organizationId: 'org',
        branchId: 'branch',
        actorUserId: 'user',
      );
      expect(await processor.processPending(context), 0);
      expect(puts, 0);
      await (db.update(db.syncOutboxEntries)
            ..where((r) => r.operationId.equals('create')))
          .write(const SyncOutboxEntriesCompanion(status: Value('succeeded')));
      expect(await processor.processPending(context), 0);
      expect(puts, 1);
      expect(
        (await db.select(db.productImages).getSingle()).uploadStatus,
        'failed',
      );
      expect(await processor.processPending(context), 0);
      expect(puts, 1);
      fail = false;
      clock.value = clock.value.add(const Duration(hours: 2));
      final results = await Future.wait([
        processor.processPending(context),
        processor.processPending(context),
      ]);
      expect(results, [1, 1]);
      expect(puts, 2);
      expect(
        (await db.select(db.productImages).getSingle()).uploadStatus,
        'uploaded',
      );
      expect((await db.select(db.products).get()).length, 1);
      expect(
        (await db.select(db.syncOutboxEntries).getSingle()).status,
        'succeeded',
      );
      // The stable image ID cannot silently acquire changed bytes after an interrupted retry.
      await (db.update(
        db.productImages,
      )).write(const ProductImagesCompanion(uploadStatus: Value('pending')));
      await file.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 1]);
      expect(await processor.processPending(context), 0);
      expect(puts, 2);
      enabled = false;
      clock.value = clock.value.add(const Duration(hours: 2));
      expect(await processor.processPending(context), 0);
      expect(puts, 2);
    },
  );
}

class _Clock implements AppClock {
  _Clock(this.value);
  DateTime value;
  @override
  DateTime nowUtc() => value;
}

Future<void> _seed(AppDatabase db, DateTime now, String file) async {
  await db
      .into(db.organizations)
      .insert(
        OrganizationsCompanion.insert(
          id: 'org',
          code: 'ORG',
          name: 'Organization',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.units)
      .insert(
        UnitsCompanion.insert(
          id: 'unit',
          organizationId: 'org',
          code: 'pc',
          name: 'Piece',
          abbreviation: 'pc',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.products)
      .insert(
        ProductsCompanion.insert(
          id: 'product',
          organizationId: 'org',
          unitId: 'unit',
          sku: 'PIC',
          normalizedSku: 'pic',
          name: 'Picture',
          normalizedName: 'picture',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.productImages)
      .insert(
        ProductImagesCompanion.insert(
          id: 'image',
          organizationId: 'org',
          productId: 'product',
          localPath: Value(file),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.syncOutboxEntries)
      .insert(
        SyncOutboxEntriesCompanion.insert(
          operationId: 'create',
          organizationId: const Value('org'),
          commandType: 'product.create',
          aggregateType: 'product',
          aggregateId: 'product',
          payloadJson: '{}',
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
      );
}
