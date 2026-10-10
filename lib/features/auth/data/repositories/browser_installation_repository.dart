import 'package:uuid/uuid.dart';
import '../../../../core/database/daos/metadata_dao.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/device_registration_repository.dart';

class BrowserInstallationRepository implements DeviceRegistrationRepository {
  const BrowserInstallationRepository(this.metadata);
  final MetadataDao metadata;
  @override
  Future<String> deviceId() async {
    final existing = await metadata.readValue('browser.id');
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await metadata.writeValue(
      key: 'browser.id',
      value: id,
      updatedAt: DateTime.now().toUtc(),
    );
    return id;
  }

  @override
  Future<void> register(AuthSession session) async {
    await deviceId();
  }
}
