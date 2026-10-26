import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../error/failure.dart';
import '../error/failures.dart';

final onlineAvailabilityServiceProvider = Provider<OnlineAvailabilityService>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return OnlineAvailabilityService(client);
});

class OnlineAvailabilityService {
  const OnlineAvailabilityService(this._client);

  final http.Client _client;

  Future<bool> isReady(AppConfig config) async {
    if (!config.onlineOnly) return true;
    final origin = config.apiBaseUri;
    if (origin == null) return false;
    try {
      final response = await _client
          .get(origin.resolve('/health/ready'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<void> ensureReady(AppConfig config) async {
    if (!await isReady(config)) {
      throw const NetworkFailure(
        'The hosted service is unavailable. Online access is required.',
        code: 'online_required',
      );
    }
  }

  Future<Failure?> mutationPrecondition(AppConfig config) async {
    if (await isReady(config)) return null;
    return const NetworkFailure(
      'This deployment is online-only. Reconnect before saving changes.',
      code: 'online_required',
    );
  }
}
