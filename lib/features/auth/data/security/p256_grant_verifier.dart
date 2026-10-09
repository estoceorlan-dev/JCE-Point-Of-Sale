import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import '../../domain/offline/offline_grant.dart';
import 'p256_device_key.dart';

class P256GrantVerifier implements OfflineGrantVerifier {
  P256GrantVerifier({
    required this.deploymentId,
    required this.trustedKeys,
    this.maxAge = const Duration(days: 7),
    this.cashierPermissions = const {'sales.process'},
  });
  final String deploymentId;
  // Public keys are pinned by the trusted installation profile, never by a JWT header.
  final Map<String, Map<String, String>> trustedKeys;
  final Duration maxAge;
  final Set<String> cashierPermissions;

  @override
  OfflineGrant verify(
    String authorization, {
    required String deviceId,
    required String keyThumbprint,
    required DateTime now,
  }) {
    if (authorization.length > 16384) {
      throw const FormatException('Invalid offline credential.');
    }
    final parts = authorization.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid offline credential.');
    }
    final header = jsonDecode(utf8.decode(base64UrlDecode(parts[0]))) as Map;
    final key = trustedKeys[header['kid']];
    if (header['alg'] != 'ES256' ||
        header['typ'] != 'JCE-OFFLINE' ||
        key == null ||
        key['kty'] != 'EC' ||
        key['crv'] != 'P-256') {
      throw const FormatException('Untrusted offline credential.');
    }
    final domain = ECDomainParameters('prime256v1');
    final point = domain.curve.decodePoint(
      Uint8List.fromList([
        4,
        ...base64UrlDecode(key['x']!),
        ...base64UrlDecode(key['y']!),
      ]),
    );
    final signature = base64UrlDecode(parts[2]);
    if (signature.length != 64) {
      throw const FormatException('Invalid signature.');
    }
    final verifier = ECDSASigner(SHA256Digest())
      ..init(false, PublicKeyParameter(ECPublicKey(point, domain)));
    if (!verifier.verifySignature(
      Uint8List.fromList(utf8.encode('${parts[0]}.${parts[1]}')),
      ECSignature(
        unsignedInteger(signature.sublist(0, 32)),
        unsignedInteger(signature.sublist(32)),
      ),
    )) {
      throw const FormatException('Invalid signature.');
    }
    final claims = jsonDecode(utf8.decode(base64UrlDecode(parts[1]))) as Map;
    String text(String name) {
      final value = claims[name];
      if (value is! String || value.isEmpty) {
        throw const FormatException('Invalid claim.');
      }
      return value;
    }

    final issued = DateTime.fromMillisecondsSinceEpoch(
      (claims['iat'] as int) * 1000,
      isUtc: true,
    );
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      (claims['exp'] as int) * 1000,
      isUtc: true,
    );
    final permissions = (claims['permissions'] as List).cast<String>().toSet();
    if (text('iss') != deploymentId ||
        text('deploymentId') != deploymentId ||
        text('aud') != 'jce-offline-cashier-v1' ||
        text('deviceId') != deviceId ||
        text('keyThumbprint') != keyThumbprint ||
        (claims['credentialVersion'] as int) < 1 ||
        !expiry.isAfter(issued) ||
        expiry.difference(issued) > maxAge ||
        !now.isBefore(expiry) ||
        issued.isAfter(now.add(const Duration(minutes: 2))) ||
        permissions.any((code) => !cashierPermissions.contains(code))) {
      throw const FormatException(
        'Offline credential expired or does not match this installation.',
      );
    }
    return OfflineGrant(
      enrollmentId: text('jti'),
      deploymentId: deploymentId,
      identityId: text('identityId'),
      userId: text('userId'),
      organizationId: text('organizationId'),
      branchId: text('branchId'),
      deviceId: deviceId,
      keyThumbprint: keyThumbprint,
      displayName: text('displayName'),
      permissions: Set.unmodifiable(permissions),
      issuedAt: issued,
      expiresAt: expiry,
    );
  }
}
