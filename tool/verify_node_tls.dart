import 'dart:convert';
import 'dart:io';
import 'package:jce_pos/features/auth/data/security/node_http_client_io.dart';

// Test harness for a disposable Caddy loopback CA; it never installs OS trust.
Future<void> main() async {
  final origin = Uri.parse(Platform.environment['JCE_TLS_TEST_ORIGIN']!);
  final pem = await File(
    Platform.environment['JCE_TLS_TEST_CA_FILE']!,
  ).readAsBytes();
  final trusted = createNodeHttpClient(certificateBase64: base64Encode(pem));
  final ordinary = createNodeHttpClient(certificateBase64: '');
  try {
    final response = await trusted.get(origin.resolve('/v1/test'));
    if (response.statusCode != 200 ||
        response.body != 'authenticated-proxy-https') {
      throw StateError('Trusted HTTPS proxy response failed.');
    }
    var rejected = false;
    try {
      await ordinary.get(origin.resolve('/v1/test'));
    } catch (_) {
      rejected = true;
    }
    if (!rejected) {
      throw StateError(
        'The disposable untrusted CA was unexpectedly accepted.',
      );
    }
    rejected = false;
    try {
      await trusted.get(origin.replace(host: 'localhost').resolve('/v1/test'));
    } catch (_) {
      rejected = true;
    }
    if (!rejected) {
      throw StateError('The incorrect hostname was unexpectedly accepted.');
    }
    try {
      createNodeHttpClient(
        certificateBase64: base64Encode(
          utf8.encode('-----BEGIN PRIVATE KEY-----'),
        ),
      );
      throw StateError('Private key input was unexpectedly accepted.');
    } on FormatException {
      /* Required rejection. */
    }
    stdout.writeln(
      'Native Dart TLS trust, untrusted-CA and hostname checks passed.',
    );
  } finally {
    trusted.close();
    ordinary.close();
  }
}
