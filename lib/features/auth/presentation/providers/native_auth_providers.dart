import '../../data/repositories/browser_api_session_repository.dart';
import '../../data/security/browser_session_platform.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/config/node_installation_profile.dart';
import '../../../../core/sync/node_actor_evidence.dart';
import '../../../../core/sync/node_device_transport.dart';
import '../../data/security/installation_binding.dart';
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

final nativeAuthProfileProvider = Provider<NativeAuthProfile>(
  (ref) => nodeInstallationProfile(),
);
final nativeAuthApiProvider = Provider<NativeAuthApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return NativeAuthApi(client, ref.watch(nativeAuthProfileProvider));
});
final installationBindingProvider = Provider<InstallationBinding>((ref) {
  final api = ref.watch(nativeAuthApiProvider);
  final binding = InstallationBinding(
    api,
    ref.watch(nativeCredentialRecordsProvider),
  );
  api.beforeRequest = binding.verify;
  return binding;
});
final nodeDeviceTransportProvider = Provider<NodeDeviceTransport>(
  (ref) => NodeDeviceTransport(
    ref.watch(nativeApiSessionRepositoryProvider),
    ref.watch(nativeInstallationStoreProvider),
    web: kIsWeb,
  ),
);
final nativeCredentialRecordsProvider = Provider<CredentialRecordStore>(
  (ref) => CredentialRecordStore(
    kIsWeb ? browserMetadataVault() : NativeCredentialVault(),
    ref.watch(nativeAuthProfileProvider).deploymentId,
  ),
);
final nativeInstallationStoreProvider = Provider<NativeInstallationStore>(
  (ref) => NativeInstallationStore(ref.watch(nativeCredentialRecordsProvider)),
);
final nativeApiSessionRepositoryProvider = Provider<NativeApiSessionRepository>(
  (ref) {
    ref.watch(installationBindingProvider);
    if (kIsWeb) {
      return BrowserApiSessionRepository(
        ref.watch(nativeAuthApiProvider),
        ref.watch(nativeCredentialRecordsProvider),
      );
    }
    return NativeApiSessionRepository(
      ref.watch(nativeAuthApiProvider),
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

final nodeActorEvidenceProvider = Provider<NodeActorEvidence>(
  (ref) => NodeActorEvidence(
    ref.watch(nodeDeviceTransportProvider),
    ref.watch(nativeInstallationStoreProvider),
    ref.watch(offlinePinRepositoryProvider),
  ),
);
