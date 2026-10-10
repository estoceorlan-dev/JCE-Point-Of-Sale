import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../domain/offline/credential_vault.dart';

// One encrypted record makes counters, credentials and clock state a single write.
// Provide one shared instance per installation profile through dependency injection.
class CredentialRecordStore {
  CredentialRecordStore(this.vault, this.deploymentId)
    : key = 'jce.auth.v1.${sha256.convert(utf8.encode(deploymentId))}';
  final CredentialVault vault;
  final String deploymentId;
  final String key;
  Future<void> _tail = Future.value();

  Future<T> transact<T>(
    Future<T> Function(Map<String, dynamic>) action, {
    bool requireWrite = false,
  }) {
    final result = _tail.then((_) async {
      final encoded = await vault.read(key);
      final state = encoded == null
          ? <String, dynamic>{'deploymentId': deploymentId}
          : Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      if (state['deploymentId'] != deploymentId) {
        throw StateError('Deployment mismatch.');
      }
      final value = await action(state);
      final updated = jsonEncode(state);
      if (requireWrite || updated != encoded) await vault.write(key, updated);
      return value;
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
