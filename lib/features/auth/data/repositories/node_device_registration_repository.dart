import 'dart:convert';
import '../../../../core/database/daos/metadata_dao.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/device_registration_repository.dart';
import '../security/native_installation_store.dart';
import 'native_api_session_repository.dart';

class NodeDeviceRegistrationRepository implements DeviceRegistrationRepository {
  const NodeDeviceRegistrationRepository(
    this.sessions,
    this.installation,
    this.metadata,
    this.platform,
  );
  final NativeApiSessionRepository sessions;
  final NativeInstallationStore installation;
  final MetadataDao metadata;
  final String platform;
  @override
  Future<String> deviceId() async => (await installation.load()).deviceId;
  @override
  Future<void> register(AuthSession session) async {
    final device = await installation.load();
    final existing = await installation.records.transact(
      (state) async => state['deviceScope'] as Map?,
    );
    if (existing != null &&
        (existing['organizationId'] != session.activeOrganizationId ||
            existing['branchId'] != session.activeBranchId)) {
      throw const AuthorizationFailure(
        'This installation is registered to a different branch. Use its assigned branch.',
      );
    }
    final challenge = await sessions.authenticated(
      '/v1/devices/challenges',
      body: {'deviceId': device.deviceId, 'purpose': 'register'},
    );
    await sessions.authenticated(
      '/v1/devices/register',
      body: {
        'deviceId': device.deviceId,
        'branchId': session.activeBranchId,
        'challenge': challenge['challenge'],
        'signature': device.key.sign(
          jsonEncode([
            'jce-device-proof-v1',
            'register',
            installation.records.deploymentId,
            session.activeOrganizationId,
            session.user.identityId,
            device.deviceId,
            challenge['challenge'],
            session.activeBranchId,
            device.key.thumbprint,
          ]),
        ),
        'publicKey': device.key.publicKey,
        'platform': platform,
        'displayName': 'POS installation',
      },
    );
    await installation.records.transact((state) async {
      state['deviceScope'] = {
        'organizationId': session.activeOrganizationId,
        'branchId': session.activeBranchId,
      };
    });
    await metadata.writeValue(
      key: 'device.id',
      value: device.deviceId,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
