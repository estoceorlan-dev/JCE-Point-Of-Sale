import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_windows/flutter_secure_storage_windows.dart';
import 'package:path/path.dart' as paths;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:uuid/uuid.dart';
import 'package:jce_pos/features/auth/data/security/native_credential_vault.dart';
import 'package:jce_pos/features/auth/data/security/credential_record_store.dart';
import 'package:jce_pos/features/auth/data/security/native_installation_store.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.directory);
  final String directory;
  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Windows DPAPI protects credentials and installation keys across adapter recreation',
    () async {
      final root = await Directory(
        '.tmp/native-auth-tests',
      ).create(recursive: true);
      final directory = await Directory(
        paths.join(root.path, const Uuid().v4()),
      ).create();
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TestPaths(directory.absolute.path);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      FlutterSecureStorageWindows.registerWith();
      try {
        final first = CredentialRecordStore(
          NativeCredentialVault(),
          'native-smoke-deployment',
        );
        final device = await NativeInstallationStore(first).load();
        const secret = 'test-session-secret-must-not-appear-on-disk';
        await first.transact((state) async {
          state['session'] = {'accessToken': secret};
        });
        FlutterSecureStorageWindows.registerWith();
        final second = CredentialRecordStore(
          NativeCredentialVault(),
          'native-smoke-deployment',
        );
        expect(
          (await NativeInstallationStore(second).load()).key.thumbprint,
          device.key.thumbprint,
        );
        expect(
          await second.transact(
            (state) async => (state['session'] as Map)['accessToken'],
          ),
          secret,
        );
        final files = directory.listSync().whereType<File>().toList();
        expect(files, isNotEmpty);
        for (final file in files) {
          final contents = latin1.decode(file.readAsBytesSync());
          expect(contents.contains(secret), false);
          expect(contents.contains(device.key.encode()), false);
        }
        await second.vault.delete(second.key);
        expect(await second.vault.read(second.key), null);
      } finally {
        PathProviderPlatform.instance = previousPaths;
        debugDefaultTargetPlatformOverride = null;
        final resolved = await directory.resolveSymbolicLinks();
        final boundary = await root.resolveSymbolicLinks();
        if (!paths.isWithin(boundary, resolved)) {
          throw StateError('Unsafe temporary test cleanup path.');
        }
        await Directory(resolved).delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
}
