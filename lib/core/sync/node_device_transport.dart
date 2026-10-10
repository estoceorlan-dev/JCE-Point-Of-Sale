import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../features/auth/data/repositories/native_api_session_repository.dart';
import '../../features/auth/data/security/native_installation_store.dart';
import '../error/failures.dart';
import 'canonical_json.dart';

class NodeDeviceTransport {
  const NodeDeviceTransport(
    this.sessions,
    this.installation, {
    this.web = false,
  });
  final NativeApiSessionRepository sessions;
  final NativeInstallationStore installation;
  final bool web;
  Future<Map<String, String>> headers(
    String method,
    String path,
    Object? body,
  ) async {
    final device = await installation.load();
    final scope = await installation.records.transact(
      (state) async => state['deviceScope'] as Map?,
    );
    if (scope == null) {
      throw const AuthenticationFailure(
        'Register this installation online first.',
      );
    }
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final nonce = const Uuid().v4().replaceAll('-', '');
    final signature = device.key.sign(
      jsonEncode([
        'jce-request-v1',
        installation.records.deploymentId,
        scope['organizationId'],
        device.deviceId,
        method,
        path,
        jsonDigest(body),
        timestamp,
        nonce,
      ]),
    );
    return {
      'X-JCE-Device-Proof': base64UrlEncode(
        utf8.encode(
          jsonEncode({
            'organizationId': scope['organizationId'],
            'deviceId': device.deviceId,
            'timestamp': timestamp,
            'nonce': nonce,
            'signature': signature,
          }),
        ),
      ).replaceAll('=', ''),
    };
  }

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? body,
  }) async {
    if (web) {
      if (body != null && body['identityId'] != null) {
        final access = await sessions.authenticated(
          '/v1/auth/access',
          method: 'GET',
        );
        if (body['identityId'] != access['identityId']) {
          throw const AuthorizationFailure(
            'Sign in as the original author to upload this browser operation.',
          );
        }
      }
      return sessions.authenticated(
        path,
        method: method,
        body: body,
        syncRequest: true,
      );
    }
    return sessions.api.request(
      path,
      method: method,
      body: body,
      syncRequest: true,
      headers: await headers(method, path, body),
    );
  }

  Future<String> authorizeActor() async {
    const path = '/v1/sync/actor-authorizations';
    final result = await sessions.authenticated(
      path,
      body: {},
      headers: await headers('POST', path, {}),
    );
    return result['authorization'] as String;
  }
}
