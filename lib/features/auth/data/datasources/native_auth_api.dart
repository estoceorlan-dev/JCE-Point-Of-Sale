import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/failure.dart';
import '../../../../core/remote/remote_api_exception.dart';
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
  Future<void> Function()? beforeRequest;
  final http.Client client;
  final NativeAuthProfile profile;

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? body,
    String? accessToken,
    Map<String, String> headers = const {},
    bool syncRequest = false,
  }) async {
    try {
      if (path != '/v1/meta') await beforeRequest?.call();
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
      request.headers.addAll(headers);
      if (accessToken != null) {
        request.headers['authorization'] = 'Bearer $accessToken';
      }
      if (body != null || !{'GET', 'HEAD'}.contains(method)) {
        request.body = jsonEncode(body ?? <String, dynamic>{});
      }
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 15),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > (syncRequest ? 8388608 : 1048576)) {
          throw const FormatException('Response too large.');
        }
      }
      final value = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (syncRequest &&
          (response.statusCode < 200 || response.statusCode >= 300)) {
        throw RemoteApiException(
          response.statusCode == 429
              ? 'resource-exhausted'
              : value['code'] as String? ?? 'unavailable',
          message: value['message'] as String?,
          details: value['details'],
          status: response.statusCode,
        );
      }
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
    } on RemoteApiException {
      rethrow;
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
