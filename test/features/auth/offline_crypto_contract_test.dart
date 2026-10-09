import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/features/auth/data/security/p256_device_key.dart';
import 'package:jce_pos/features/auth/data/security/p256_grant_verifier.dart';
import 'package:jce_pos/features/auth/data/security/argon_pin_hasher.dart';

void main() {
  test(
    'Dart verifies the Node.js ES256 credential and matches installation key identity',
    () {
      final fixture =
          jsonDecode(
                File('test/fixtures/offline_auth_v1.json').readAsStringSync(),
              )
              as Map;
      final key = Map<String, String>.from(fixture['verificationKey'] as Map);
      final device = P256DeviceKey.decode(
        fixture['devicePrivateTestScalar'] as String,
      );
      expect(device.publicKey, fixture['devicePublicKey']);
      expect(device.thumbprint, fixture['claims']['keyThumbprint']);
      final verifier = P256GrantVerifier(
        deploymentId: 'deployment-test',
        trustedKeys: {key['kid']!: key},
      );
      final grant = verifier.verify(
        fixture['authorization'] as String,
        deviceId: 'device-test',
        keyThumbprint: device.thumbprint,
        now: DateTime.utc(2026, 10, 7, 1),
      );
      expect(grant.permissions, {'sales.process'});
      expect(grant.canApproveAsSupervisor, false);
      expect(
        () => verifier.verify(
          fixture['authorization'] as String,
          deviceId: 'wrong-device',
          keyThumbprint: device.thumbprint,
          now: DateTime.utc(2026, 10, 7),
        ),
        throwsFormatException,
      );
      final pieces = (fixture['authorization'] as String).split('.');
      pieces[1] = base64Url(
        utf8.encode(
          jsonEncode({
            ...Map<String, dynamic>.from(fixture['claims'] as Map),
            'identityId': 'attacker',
          }),
        ),
      );
      expect(
        () => verifier.verify(
          pieces.join('.'),
          deviceId: 'device-test',
          keyThumbprint: device.thumbprint,
          now: DateTime.utc(2026, 10, 7),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'PIN hashing uses salted Argon2id and verifies independently',
    () async {
      const hasher = ArgonPinHasher();
      final first = await hasher.hash('123456');
      final second = await hasher.hash('123456');
      expect(first['hash'], isNot(second['hash']));
      expect(await hasher.verify('123456', first), true);
      expect(await hasher.verify('654321', first), false);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
