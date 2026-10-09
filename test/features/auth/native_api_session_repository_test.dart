import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/features/auth/domain/offline/native_auth_profile.dart';
import 'package:jce_pos/features/auth/data/datasources/native_auth_api.dart';
import 'package:jce_pos/features/auth/data/repositories/native_api_session_repository.dart';
import 'package:jce_pos/features/auth/data/security/credential_record_store.dart';
import 'native_auth_test_support.dart';

void main() {
  final profile = NativeAuthProfile(
    deploymentId: 'deployment',
    organizationCode: 'org',
    apiOrigin: Uri.parse('https://branch.example.test'),
    offlineVerificationKeys: const {},
  );
  final access = {
    'deploymentId': 'deployment',
    'identityId': 'cashier',
    'userId': 'staff',
    'organizationId': 'org',
    'displayName': 'Cashier',
    'organizationPermissions': <String>[],
    'branches': [
      {
        'id': 'branch',
        'name': 'Branch',
        'permissions': ['sales.process'],
      },
    ],
  };
  Map<String, Object> tokens(String value) => {
    'deploymentId': 'deployment',
    'accessToken': 'access-$value',
    'refreshToken': 'refresh-$value',
  };
  http.Response response(Map value, [int code = 200]) =>
      http.Response(jsonEncode(value), code);

  test(
    'refresh is serialized, credentials survive recreation and revocation quarantines offline credentials',
    () async {
      final vault = MemoryVault();
      final records = CredentialRecordStore(vault, 'deployment');
      var expired = false;
      var refreshes = 0;
      var revoked = false;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/login')) return response(tokens('one'));
        if (request.url.path.endsWith('/refresh')) {
          refreshes++;
          if (revoked) return response({'code': 'unauthorized'}, 401);
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return response(tokens('two'));
        }
        if (expired &&
            (revoked ||
                request.headers['authorization'] == 'Bearer access-one')) {
          return response({'code': 'unauthorized'}, 401);
        }
        return response(access);
      });
      final api = NativeAuthApi(client, profile);
      var sessions = NativeApiSessionRepository(api, records);
      expect(
        (await sessions.signIn('cashier@example.com', 'password')).isSuccess,
        true,
      );
      sessions = NativeApiSessionRepository(
        api,
        CredentialRecordStore(vault, 'deployment'),
      );
      expired = true;
      await Future.wait(
        List.generate(
          4,
          (_) => sessions.authenticated('/v1/auth/access', method: 'GET'),
        ),
      );
      expect(refreshes, 1);
      await sessions.records.transact((state) async {
        state['enrollments'] = {
          'cashier:branch': {'reauthenticationRequired': false},
        };
        state['queuedActorEvidence'] = ['cashier'];
      });
      revoked = true;
      await expectLater(
        sessions.authenticated('/v1/auth/access', method: 'GET'),
        throwsA(isA<AuthenticationFailure>()),
      );
      await sessions.records.transact((state) async {
        expect(state['session'], isNull);
        expect(
          state['enrollments']['cashier:branch']['reauthenticationRequired'],
          true,
        );
        expect(state['queuedActorEvidence'], ['cashier']);
      });
    },
  );

  test(
    'a different deployment cannot replace credentials; wrong passwords do not trigger refresh',
    () async {
      final records = CredentialRecordStore(MemoryVault(), 'deployment');
      var mismatch = true;
      var refreshed = false;
      final api = NativeAuthApi(
        MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return response({
              ...tokens('one'),
              if (mismatch) 'deploymentId': 'wrong',
            });
          }
          if (request.url.path.endsWith('/refresh')) refreshed = true;
          if (request.url.path.endsWith('/offline-enrollments')) {
            return response({'code': 'invalid_credentials'}, 401);
          }
          return response(access);
        }),
        profile,
      );
      final sessions = NativeApiSessionRepository(api, records);
      expect(
        (await sessions.signIn('email', 'password')).failureOrNull,
        isA<AuthenticationFailure>(),
      );
      expect(await records.transact((state) async => state['session']), null);
      mismatch = false;
      expect((await sessions.signIn('email', 'password')).isSuccess, true);
      await expectLater(
        sessions.authenticated('/v1/auth/offline-enrollments'),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(refreshed, false);
      await expectLater(
        api.request(
          'https://other.example.test/v1/auth/access',
          accessToken: 'secret',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    },
  );
}
