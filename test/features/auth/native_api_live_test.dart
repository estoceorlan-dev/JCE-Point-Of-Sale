import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jce_pos/features/auth/domain/offline/native_auth_profile.dart';
import 'package:jce_pos/features/auth/data/datasources/native_auth_api.dart';
import 'package:jce_pos/features/auth/data/datasources/native_enrollment_source.dart';
import 'package:jce_pos/features/auth/data/repositories/native_api_session_repository.dart';
import 'package:jce_pos/features/auth/data/repositories/secure_offline_pin_repository.dart';
import 'package:jce_pos/features/auth/data/security/credential_record_store.dart';
import 'package:jce_pos/features/auth/data/security/native_installation_store.dart';
import 'package:jce_pos/features/auth/data/security/p256_grant_verifier.dart';
import 'native_auth_test_support.dart';

class _NetworkGate extends http.BaseClient {
  final delegate = http.Client();
  bool online = true;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!online) throw http.ClientException('Simulated API outage');
    return delegate.send(request);
  }

  @override
  void close() => delegate.close();
}

void main() {
  final encoded = Platform.environment['JCE_AUTH_LIVE_PROFILE'];
  test(
    'real API: password login, device proof, enrollment, restart, PIN lock and online recovery',
    () async {
      final config = jsonDecode(encoded!) as Map;
      final key = Map<String, String>.from(config['verificationKey'] as Map);
      final profile = NativeAuthProfile(
        deploymentId: config['deploymentId'] as String,
        organizationCode: config['organizationCode'] as String,
        apiOrigin: Uri.parse(config['origin'] as String),
        offlineVerificationKeys: {key['kid']!: key},
        allowHttpLoopback: true,
      );
      final vault = MemoryVault();
      final network = _NetworkGate();
      final records = CredentialRecordStore(vault, profile.deploymentId);
      final installation = NativeInstallationStore(records);
      final sessions = NativeApiSessionRepository(
        NativeAuthApi(network, profile),
        records,
      );
      var clock = DateTime.now().toUtc();
      final remote = NativeEnrollmentSource(
        sessions: sessions,
        installation: installation,
        platform: 'windows',
        displayName: 'Contract test',
      );
      SecureOfflinePinRepository pins() => SecureOfflinePinRepository(
        records: records,
        installation: installation,
        remote: remote,
        verifier: P256GrantVerifier(
          deploymentId: profile.deploymentId,
          trustedKeys: profile.offlineVerificationKeys,
        ),
        hasher: FastTestPinHasher(),
        now: () => clock,
      );
      try {
        final signedIn = await sessions.signIn(
          config['email'] as String,
          config['password'] as String,
        );
        expect(signedIn.isSuccess, true, reason: '${signedIn.failureOrNull}');
        final enrolled = await pins().enroll(
          password: config['password'] as String,
          pin: '123456',
          branchId: config['branchId'] as String,
        );
        expect(enrolled.isSuccess, true, reason: '${enrolled.failureOrNull}');
        network.online = false;
        final identityId = signedIn.valueOrNull!.identityId;
        final branchId = config['branchId'] as String;
        final restartedRecords = CredentialRecordStore(
          vault,
          profile.deploymentId,
        );
        final restarted = SecureOfflinePinRepository(
          records: restartedRecords,
          installation: NativeInstallationStore(restartedRecords),
          remote: remote,
          verifier: P256GrantVerifier(
            deploymentId: profile.deploymentId,
            trustedKeys: profile.offlineVerificationKeys,
          ),
          hasher: FastTestPinHasher(),
          now: () => clock,
        );
        expect(
          (await restarted.signIn(
            identityId: identityId,
            branchId: branchId,
            pin: '123456',
          )).isSuccess,
          true,
        );
        for (var i = 0; i < 5; i++) {
          await restarted.signIn(
            identityId: identityId,
            branchId: branchId,
            pin: '000000',
          );
        }
        expect(
          (await restarted.signIn(
            identityId: identityId,
            branchId: branchId,
            pin: '123456',
          )).isFailure,
          true,
        );
        clock = clock.add(const Duration(minutes: 15));
        for (var i = 0; i < 5; i++) {
          await restarted.signIn(
            identityId: identityId,
            branchId: branchId,
            pin: '000000',
          );
        }
        expect(
          (await restarted.signIn(
            identityId: identityId,
            branchId: branchId,
            pin: '123456',
          )).isFailure,
          true,
        );
        network.online = true;
        expect(
          (await restarted.enroll(
            password: config['password'] as String,
            pin: '654321',
            branchId: branchId,
          )).isSuccess,
          true,
        );
        network.online = false;
        expect(
          (await restarted.signIn(
            identityId: identityId,
            branchId: branchId,
            pin: '654321',
          )).isSuccess,
          true,
        );
      } finally {
        network.close();
      }
    },
    skip: encoded == null,
  );
}
