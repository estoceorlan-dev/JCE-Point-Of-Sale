import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/offline/credential_vault.dart';

class NativeCredentialVault implements CredentialVault {
  NativeCredentialVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  void _requireNative() {
    if (kIsWeb ||
        !{
          TargetPlatform.windows,
          TargetPlatform.android,
        }.contains(defaultTargetPlatform)) {
      throw UnsupportedError(
        'Native authentication requires Windows or Android secure storage.',
      );
    }
  }

  @override
  Future<String?> read(String key) {
    _requireNative();
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    _requireNative();
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    _requireNative();
    return _storage.delete(key: key);
  }
}
