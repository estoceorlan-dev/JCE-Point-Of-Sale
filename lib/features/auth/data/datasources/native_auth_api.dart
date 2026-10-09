import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../domain/offline/native_auth_profile.dart';

class NativeAuthApi {
  NativeAuthApi(this.client, this.profile) {
    final uri = profile.apiOrigin;
    final local =
        profile.allowHttpLoopback &&
        uri.scheme == 'http' &&
        {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
    if ((uri.scheme != 'https' && !local) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError('A trusted HTTPS API origin is required.');
    }
  }
  final http.Client client;
  final NativeAuthProfile profile;

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    try {
      final target = profile.apiOrigin.resolve(path);
      if (!path.startsWith('/v1/') ||
          target.origin != profile.apiOrigin.origin) {
        throw const ValidationFailure(
          'Authentication requests must use the configured deployment.',
        );
      }
      final request = http.Request(method, target)
        ..followRedirects = false
        ..headers['content-type'] = 'application/json';
      if (accessToken != null) {
        request.headers['authorization'] = 'Bearer $accessToken';
      }
      if (body != null) request.body = jsonEncode(body);
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 15),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > 1048576) {
          throw const FormatException('Response too large.');
        }
      }
      final value = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (response.statusCode == 401) {
        throw AuthenticationFailure(
          'API authentication required.',
          code: value['code'] as String?,
        );
      }
      if (response.statusCode == 403) {
        throw AuthorizationFailure(
          'API access denied.',
          code: value['code'] as String?,
        );
      }
      if (response.statusCode == 429) {
        throw const AuthenticationFailure(
          'Too many attempts. Try again later.',
          code: 'rate_limited',
        );
      }
      if (response.statusCode >= 500) {
        throw const NetworkFailure(
          'API service unavailable.',
          code: 'service_unavailable',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ValidationFailure('The API could not accept this request.');
      }
      return value;
    } on Failure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure(
        'Unable to reach the configured API.',
        code: 'api_unavailable',
      );
    }
  }
}
