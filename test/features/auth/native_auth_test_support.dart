import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:jce_pos/features/auth/domain/offline/credential_vault.dart';
import 'package:jce_pos/features/auth/domain/offline/offline_pin_repository.dart';
import 'package:jce_pos/features/auth/data/security/p256_device_key.dart';
import 'package:jce_pos/features/auth/data/security/native_installation_store.dart';

class MemoryVault implements CredentialVault {
  final values = <String, String>{};
  bool failWrites = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('Injected storage error');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FastTestPinHasher implements PinHasher {
  @override
  Future<Map<String, String>> hash(String pin) async => {
    'hash': sha256.convert(utf8.encode(pin)).toString(),
  };
  @override
  Future<bool> verify(String pin, Map<String, String> encoded) async =>
      encoded['hash'] == (await hash(pin))['hash'];
}

class TestEnrollmentSource implements OfflineEnrollmentSource {
  TestEnrollmentSource(this.installation, this.now);
  final NativeInstallationStore installation;
  final DateTime Function() now;
  final signer = P256DeviceKey(BigInt.one);
  String identityId = 'cashier-a';
  int issued = 0;
  bool offline = false;
  String? replay;
  @override
  Future<String> authorize({
    required String password,
    required String branchId,
  }) async {
    if (offline) throw StateError('API unavailable');
    if (replay != null) return replay!;
    final device = await installation.load();
    final time = now().millisecondsSinceEpoch ~/ 1000;
    final claims = {
      'iss': installation.records.deploymentId,
      'aud': 'jce-offline-cashier-v1',
      'jti': 'enrollment-${++issued}',
      'iat': time,
      'exp': time + 7 * 86400,
      'deploymentId': installation.records.deploymentId,
      'identityId': identityId,
      'userId': '$identityId-user',
      'organizationId': 'org',
      'branchId': branchId,
      'deviceId': device.deviceId,
      'keyThumbprint': device.key.thumbprint,
      'credentialVersion': 1,
      'permissions': ['sales.process'],
      'displayName': identityId,
    };
    final header = base64Url(
      utf8.encode(
        jsonEncode({
          'alg': 'ES256',
          'typ': 'JCE-OFFLINE',
          'kid': signer.thumbprint,
        }),
      ),
    );
    final body = base64Url(utf8.encode(jsonEncode(claims)));
    final content = '$header.$body';
    return '$content.${signer.sign(content)}';
  }
}
