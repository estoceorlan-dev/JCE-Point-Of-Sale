import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Additional public branch CA, scoped by NativeAuthApi to its fixed HTTPS origin.
/// Normal certificate chain, expiry and hostname verification remain enabled.
http.Client createNodeHttpClient({String? certificateBase64}) {
  final value =
      certificateBase64 ??
      const String.fromEnvironment('JCE_TLS_CA_CERT_BASE64');
  if (value.isEmpty) return http.Client();
  if (value.length > 131072) {
    throw const FormatException('The branch CA certificate is too large.');
  }
  final bytes = base64Decode(value), pem = utf8.decode(bytes);
  if (!pem.contains('-----BEGIN CERTIFICATE-----') ||
      pem.contains('PRIVATE KEY')) {
    throw const FormatException(
      'Provide only the public branch CA certificate.',
    );
  }
  final context = SecurityContext(withTrustedRoots: true)
    ..setTrustedCertificatesBytes(bytes);
  return IOClient(HttpClient(context: context));
}
