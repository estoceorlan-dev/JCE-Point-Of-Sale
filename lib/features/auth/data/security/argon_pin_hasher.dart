import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import '../../domain/offline/credential_vault.dart';

String _derivePin(Map<String, String> input) {
  final salt = base64Decode(input['salt']!);
  if (salt.length != 16) throw const FormatException('Invalid PIN salt.');
  final algorithm = Argon2BytesGenerator()
    ..init(
      Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        salt,
        desiredKeyLength: 32,
        memory: 19456,
        iterations: 2,
        lanes: 1,
      ),
    );
  return base64Encode(
    algorithm.process(Uint8List.fromList(utf8.encode(input['pin']!))),
  );
}

class ArgonPinHasher implements PinHasher {
  const ArgonPinHasher();
  @override
  Future<Map<String, String>> hash(String pin) async {
    final random = Random.secure();
    final salt = base64Encode(List.generate(16, (_) => random.nextInt(256)));
    return {
      'version': 'argon2id-19m-2-v1',
      'salt': salt,
      'hash': await compute(_derivePin, {'pin': pin, 'salt': salt}),
    };
  }

  @override
  Future<bool> verify(String pin, Map<String, String> encoded) async {
    if (encoded['version'] != 'argon2id-19m-2-v1') return false;
    final actual = base64Decode(
      await compute(_derivePin, {'pin': pin, 'salt': encoded['salt']!}),
    );
    final expected = base64Decode(encoded['hash']!);
    if (expected.length != 32) return false;
    var difference = 0;
    for (var i = 0; i < 32; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }
}
