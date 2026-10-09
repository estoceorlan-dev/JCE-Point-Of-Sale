import 'package:uuid/uuid.dart';
import 'credential_record_store.dart';
import 'p256_device_key.dart';

class NativeInstallation {
  const NativeInstallation(this.deviceId, this.key);
  final String deviceId;
  final P256DeviceKey key;
}

class NativeInstallationStore {
  const NativeInstallationStore(this.records);
  final CredentialRecordStore records;
  Future<NativeInstallation> load() => records.transact((state) async {
    if (!state.containsKey('installation')) {
      // Never silently regenerate a lost key while enrolled users exist.
      if ((state['enrollments'] as Map?)?.isNotEmpty ?? false) {
        throw StateError('Installation recovery requires online enrollment.');
      }
      state['installation'] = {
        'deviceId': const Uuid().v4(),
        'privateKey': P256DeviceKey.generate().encode(),
      };
    }
    final value = state['installation'] as Map;
    return NativeInstallation(
      value['deviceId'] as String,
      P256DeviceKey.decode(value['privateKey'] as String),
    );
  });
}
