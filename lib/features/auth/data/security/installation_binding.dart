import '../../../../core/error/failures.dart';
import '../../../../core/sync/canonical_json.dart';
import '../datasources/native_auth_api.dart';
import 'credential_record_store.dart';

/// An address can change only after the same deployment and pinned key are verified.
class InstallationBinding {
  InstallationBinding(this.api, this.records);
  final NativeAuthApi api;
  final CredentialRecordStore records;
  Future<void>? _verification;
  Future<void> verify() =>
      _verification ??= _verify().catchError((Object error) {
        _verification = null;
        throw error;
      });
  Future<void> initialize() async {
    try {
      await verify();
    } on NetworkFailure {
      final bound = await records.transact(
        (state) async => state['boundOrigin'],
      );
      if (bound != api.profile.apiOrigin.origin) rethrow;
    }
  }

  Future<void> _verify() async {
    final meta = await api.request('/v1/meta', method: 'GET');
    if (meta['deploymentId'] != records.deploymentId ||
        !(meta['apiVersion'] as String? ?? '').startsWith('1.') ||
        (meta['databaseSchemaVersion'] as num? ?? 0) < 22 ||
        (meta['minClientProtocolVersion'] as num) > 1 ||
        (meta['maxClientProtocolVersion'] as num) < 1 ||
        (meta['capabilities'] as Map)['signedCommands'] != true) {
      throw const AuthenticationFailure(
        'This API does not match the installed deployment or client protocol.',
        code: 'deployment_mismatch',
      );
    }
    final keys = meta['offlineVerificationKeys'] as List;
    bool trusted = false;
    for (final value in keys) {
      final key = Map<String, dynamic>.from(value as Map);
      final pinned = api.profile.offlineVerificationKeys[key['kid']];
      if (pinned != null &&
          ['kty', 'crv', 'x', 'y'].every((part) => key[part] == pinned[part])) {
        trusted = true;
      }
    }
    if (!trusted) {
      throw const AuthenticationFailure(
        'The deployment signing key is not pinned by this installation.',
        code: 'deployment_mismatch',
      );
    }
    await records.transact((state) async {
      state['boundOrigin'] = api.profile.apiOrigin.origin;
      state['metadataDigest'] = jsonDigest(meta);
    });
  }
}
