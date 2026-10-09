import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../domain/offline/native_auth_profile.dart';
import '../../domain/offline/offline_pin_repository.dart';
import '../../data/datasources/native_auth_api.dart';
import '../../data/datasources/native_enrollment_source.dart';
import '../../data/repositories/native_api_session_repository.dart';
import '../../data/repositories/secure_offline_pin_repository.dart';
import '../../data/security/argon_pin_hasher.dart';
import '../../data/security/credential_record_store.dart';
import '../../data/security/native_credential_vault.dart';
import '../../data/security/native_installation_store.dart';
import '../../data/security/p256_grant_verifier.dart';

// Phase 4 supplies the verified installation profile and selects this adapter.
// Merely importing these providers never changes the existing authRepositoryProvider.
final nativeAuthProfileProvider = Provider<NativeAuthProfile>(
  (ref) =>
      throw StateError('A verified native installation profile is required.'),
);
final nativeCredentialRecordsProvider = Provider<CredentialRecordStore>(
  (ref) => CredentialRecordStore(
    NativeCredentialVault(),
    ref.watch(nativeAuthProfileProvider).deploymentId,
  ),
);
final nativeInstallationStoreProvider = Provider<NativeInstallationStore>(
  (ref) => NativeInstallationStore(ref.watch(nativeCredentialRecordsProvider)),
);
final nativeApiSessionRepositoryProvider = Provider<NativeApiSessionRepository>(
  (ref) {
    final client = http.Client();
    ref.onDispose(client.close);
    return NativeApiSessionRepository(
      NativeAuthApi(client, ref.watch(nativeAuthProfileProvider)),
      ref.watch(nativeCredentialRecordsProvider),
    );
  },
);
final offlinePinRepositoryProvider = Provider<OfflinePinRepository>((ref) {
  final profile = ref.watch(nativeAuthProfileProvider);
  final installation = ref.watch(nativeInstallationStoreProvider);
  return SecureOfflinePinRepository(
    records: ref.watch(nativeCredentialRecordsProvider),
    installation: installation,
    remote: NativeEnrollmentSource(
      sessions: ref.watch(nativeApiSessionRepositoryProvider),
      installation: installation,
      platform: defaultTargetPlatform == TargetPlatform.windows
          ? 'windows'
          : 'android',
      displayName: 'POS installation',
    ),
    verifier: P256GrantVerifier(
      deploymentId: profile.deploymentId,
      trustedKeys: profile.offlineVerificationKeys,
    ),
    hasher: const ArgonPinHasher(),
    now: DateTime.now,
  );
});
