import 'dart:convert';
import '../../../../core/error/failures.dart';
import '../../domain/offline/offline_pin_repository.dart';
import '../repositories/native_api_session_repository.dart';
import '../security/native_installation_store.dart';

class NativeEnrollmentSource implements OfflineEnrollmentSource {
  const NativeEnrollmentSource({
    required this.sessions,
    required this.installation,
    required this.platform,
    required this.displayName,
  });
  final NativeApiSessionRepository sessions;
  final NativeInstallationStore installation;
  final String platform;
  final String displayName;

  @override
  Future<String> authorize({
    required String password,
    required String branchId,
  }) async {
    final device = await installation.load();
    final access = await sessions.authenticated(
      '/v1/auth/access',
      method: 'GET',
    );
    if (access['deploymentId'] != installation.records.deploymentId) {
      throw const AuthenticationFailure(
        'Deployment mismatch.',
        code: 'deployment_mismatch',
      );
    }
    Future<Map<String, dynamic>> proof(String purpose) async {
      final challenge = await sessions.authenticated(
        '/v1/devices/challenges',
        body: {'deviceId': device.deviceId, 'purpose': purpose},
      );
      final message = jsonEncode([
        'jce-device-proof-v1',
        purpose,
        access['deploymentId'],
        access['organizationId'],
        access['identityId'],
        device.deviceId,
        challenge['challenge'],
        branchId,
        device.key.thumbprint,
      ]);
      return {
        'deviceId': device.deviceId,
        'branchId': branchId,
        'challenge': challenge['challenge'],
        'signature': device.key.sign(message),
      };
    }

    await sessions.authenticated(
      '/v1/devices/register',
      body: {
        ...await proof('register'),
        'publicKey': device.key.publicKey,
        'platform': platform,
        'displayName': displayName,
      },
    );
    final enrolled = await sessions.authenticated(
      '/v1/auth/offline-enrollments',
      body: {...await proof('enroll'), 'password': password},
    );
    return enrolled['authorization'] as String;
  }
}
