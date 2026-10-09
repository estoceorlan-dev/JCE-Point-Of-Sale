import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as hashes;
import 'package:pointycastle/export.dart';

Uint8List unsignedBytes(BigInt value, int length) {
  final bytes = Uint8List(length);
  for (var i = length - 1; i >= 0; i--) {
    bytes[i] = (value & BigInt.from(255)).toInt();
    value >>= 8;
  }
  return bytes;
}

BigInt unsignedInteger(List<int> bytes) =>
    bytes.fold(BigInt.zero, (value, byte) => (value << 8) | BigInt.from(byte));
String base64Url(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');
Uint8List base64UrlDecode(String value) =>
    base64.decode(base64.normalize(value));

class P256DeviceKey {
  P256DeviceKey(this.privateScalar) {
    if (privateScalar <= BigInt.zero || privateScalar >= _domain.n) {
      throw const FormatException('Invalid installation key.');
    }
  }
  static final _domain = ECDomainParameters('prime256v1');
  final BigInt privateScalar;
  factory P256DeviceKey.generate() {
    final entropy = Random.secure();
    final random = FortunaRandom()
      ..seed(
        KeyParameter(
          Uint8List.fromList(List.generate(32, (_) => entropy.nextInt(256))),
        ),
      );
    final generator = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(_domain), random));
    return P256DeviceKey(generator.generateKeyPair().privateKey.d!);
  }
  factory P256DeviceKey.decode(String value) =>
      P256DeviceKey(unsignedInteger(base64UrlDecode(value)));
  String encode() => base64Url(unsignedBytes(privateScalar, 32));
  Map<String, String> get publicKey {
    final point = _domain.G * privateScalar;
    return {
      'crv': 'P-256',
      'kty': 'EC',
      'x': base64Url(unsignedBytes(point!.x!.toBigInteger()!, 32)),
      'y': base64Url(unsignedBytes(point.y!.toBigInteger()!, 32)),
    };
  }

  String get thumbprint =>
      hashes.sha256.convert(utf8.encode(jsonEncode(publicKey))).toString();
  String sign(String message) {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter(ECPrivateKey(privateScalar, _domain)));
    final signature =
        signer.generateSignature(Uint8List.fromList(utf8.encode(message)))
            as ECSignature;
    return base64Url([
      ...unsignedBytes(signature.r, 32),
      ...unsignedBytes(signature.s, 32),
    ]);
  }
}
