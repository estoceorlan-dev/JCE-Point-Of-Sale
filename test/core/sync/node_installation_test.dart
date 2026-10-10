import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jce_pos/core/config/node_installation_profile.dart';
import 'package:jce_pos/core/sync/canonical_json.dart';
import 'package:jce_pos/features/auth/data/datasources/native_auth_api.dart';
import 'package:jce_pos/features/auth/data/repositories/native_api_session_repository.dart';
import 'package:jce_pos/features/auth/data/security/credential_record_store.dart';
import 'package:jce_pos/features/auth/data/security/installation_binding.dart';
import 'package:jce_pos/features/auth/domain/offline/native_auth_profile.dart';
import 'package:jce_pos/core/error/failures.dart';
import '../../features/auth/native_auth_test_support.dart';

void main() {
  const deployment = '11111111-1111-4111-8111-111111111111';
  NativeAuthProfile profile([String host = 'branch.example']) =>
      NativeAuthProfile(
        deploymentId: deployment,
        organizationCode: 'TEST',
        apiOrigin: Uri.https(host),
        offlineVerificationKeys: const {
          'key': {
            'kty': 'EC',
            'crv': 'P-256',
            'x': 'public-x',
            'y': 'public-y',
          },
        },
      );
  Map<String, Object?> meta(String identity) => {
    'deploymentId': identity,
    'apiVersion': '1.0.0',
    'databaseSchemaVersion': 22,
    'minClientProtocolVersion': 1,
    'maxClientProtocolVersion': 1,
    'capabilities': {'signedCommands': true},
    'offlineVerificationKeys': [
      {'kid': 'key', ...profile().offlineVerificationKeys['key']!},
    ],
  };
  test(
    'canonical JSON agrees on ordering and rejects imprecise command numbers',
    () {
      expect(
        canonicalJson({
          'z': [null, true, 'é😀'],
          'a': 9007199254740991,
        }),
        '{"a":9007199254740991,"z":[null,true,"é😀"]}',
      );
      expect(() => canonicalJson({'price': 1.5}), throwsFormatException);
      expect(() => canonicalJson(9007199254740992), throwsFormatException);
      expect(jsonDigest({'b': 2, 'a': 1}), jsonDigest({'a': 1, 'b': 2}));
    },
  );
  test(
    'wrong deployment is rejected before sending a password or session',
    () async {
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(request.url.path);
        return http.Response(jsonEncode(meta('other-deployment')), 200);
      });
      final records = CredentialRecordStore(MemoryVault(), deployment);
      final api = NativeAuthApi(client, profile());
      final binding = InstallationBinding(api, records);
      api.beforeRequest = binding.verify;
      final result = await NativeApiSessionRepository(
        api,
        records,
      ).signIn('cashier@example.test', 'never-transmitted');
      expect(result.failureOrNull, isA<AuthenticationFailure>());
      expect(requests, ['/v1/meta']);
      expect(await records.transact((state) async => state['session']), isNull);
      client.close();
    },
  );
  test(
    'offline restart requires a prior binding; changing the address requires verification',
    () async {
      final vault = MemoryVault();
      final records = CredentialRecordStore(vault, deployment);
      final online = MockClient(
        (_) async => http.Response(jsonEncode(meta(deployment)), 200),
      );
      await InstallationBinding(
        NativeAuthApi(online, profile()),
        records,
      ).initialize();
      final offline = MockClient(
        (_) async => throw http.ClientException('unavailable'),
      );
      await InstallationBinding(
        NativeAuthApi(offline, profile()),
        CredentialRecordStore(vault, deployment),
      ).initialize();
      await expectLater(
        InstallationBinding(
          NativeAuthApi(offline, profile('new.example')),
          records,
        ).initialize(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(
        deploymentDatabaseName(deployment),
        isNot(deploymentDatabaseName('other-deployment')),
      );
      online.close();
      offline.close();
    },
  );
}
