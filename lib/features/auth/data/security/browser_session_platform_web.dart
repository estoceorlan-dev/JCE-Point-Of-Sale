import 'dart:convert';
import 'package:web/web.dart' as web;
import '../../domain/offline/credential_vault.dart';

void requireBrowserOrigin(Uri origin) {
  if (origin.origin != web.window.location.origin) {
    throw StateError('Serve web administration from the API origin.');
  }
}

String? browserCsrf() {
  for (final cookie in web.document.cookie.split(';')) {
    final entry = cookie.trim();
    if (entry.startsWith('__Host-jce_csrf=')) {
      return Uri.decodeComponent(entry.substring('__Host-jce_csrf='.length));
    }
  }
  return null;
}

CredentialVault browserMetadataVault() => _BrowserMetadataVault();

/// Only non-secret deployment/profile metadata. Sessions remain HttpOnly cookies.
class _BrowserMetadataVault implements CredentialVault {
  @override
  Future<String?> read(String key) async =>
      web.window.localStorage.getItem(key);
  @override
  Future<void> write(String key, String value) async {
    final state = jsonDecode(value) as Map;
    if (state.containsKey('session') ||
        state.containsKey('installation') ||
        state.containsKey('enrollments')) {
      throw StateError('Native credentials must never enter browser storage.');
    }
    web.window.localStorage.setItem(key, value);
  }

  @override
  Future<void> delete(String key) async =>
      web.window.localStorage.removeItem(key);
}
