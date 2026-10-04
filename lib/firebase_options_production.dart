// Production Firebase identifiers are supplied by a validated dart-define file.
// They are intentionally not committed before the isolated backend exists.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class ProductionFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return _fromDartDefines(
        requireAuthDomain: true,
        requiredAppIdMarker: ':web:',
      );
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _fromDartDefines(
        requireAuthDomain: false,
        requiredAppIdMarker: ':android:',
      ),
      TargetPlatform.windows => throw UnsupportedError(
        'Production Windows is deferred by ADR-0001. Do not use the '
        'FlutterFire Windows configuration for a production build.',
      ),
      _ => throw UnsupportedError(
        '${defaultTargetPlatform.name} is not an approved production platform.',
      ),
    };
  }

  static FirebaseOptions _fromDartDefines({
    required bool requireAuthDomain,
    required String requiredAppIdMarker,
  }) {
    const apiKey = String.fromEnvironment('JCE_FIREBASE_API_KEY');
    const appId = String.fromEnvironment('JCE_FIREBASE_APP_ID');
    const messagingSenderId = String.fromEnvironment(
      'JCE_FIREBASE_MESSAGING_SENDER_ID',
    );
    const projectId = String.fromEnvironment('JCE_FIREBASE_PROJECT_ID');
    const approvedProjectId = String.fromEnvironment(
      'JCE_APPROVED_PRODUCTION_PROJECT_ID',
    );
    const authDomain = String.fromEnvironment('JCE_FIREBASE_AUTH_DOMAIN');
    const storageBucket = String.fromEnvironment('JCE_FIREBASE_STORAGE_BUCKET');

    return fromValues(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      approvedProjectId: approvedProjectId,
      authDomain: authDomain,
      storageBucket: storageBucket,
      requireAuthDomain: requireAuthDomain,
      requiredAppIdMarker: requiredAppIdMarker,
    );
  }

  static FirebaseOptions fromValues({
    required String apiKey,
    required String appId,
    required String messagingSenderId,
    required String projectId,
    required String approvedProjectId,
    required String storageBucket,
    String? authDomain,
    bool requireAuthDomain = false,
    String? requiredAppIdMarker,
  }) {
    final normalizedApiKey = _required(apiKey, 'JCE_FIREBASE_API_KEY');
    final normalizedAppId = _required(appId, 'JCE_FIREBASE_APP_ID');
    final normalizedSender = _required(
      messagingSenderId,
      'JCE_FIREBASE_MESSAGING_SENDER_ID',
    );
    final normalizedProject = _required(projectId, 'JCE_FIREBASE_PROJECT_ID');
    final normalizedApprovedProject = _required(
      approvedProjectId,
      'JCE_APPROVED_PRODUCTION_PROJECT_ID',
    );
    final normalizedBucket = _required(
      storageBucket,
      'JCE_FIREBASE_STORAGE_BUCKET',
    );
    final normalizedAuthDomain = authDomain?.trim();

    if (normalizedProject == 'jce-pos' ||
        normalizedProject == 'jce-pos-staging-259528' ||
        normalizedProject.contains('development') ||
        normalizedProject.contains('staging') ||
        !normalizedProject.contains('production')) {
      throw const FormatException(
        'Production Firebase configuration cannot target a non-production project.',
      );
    }
    if (normalizedProject != normalizedApprovedProject) {
      throw const FormatException(
        'JCE_FIREBASE_PROJECT_ID does not match the approved production project.',
      );
    }
    if (requireAuthDomain &&
        (normalizedAuthDomain == null || normalizedAuthDomain.isEmpty)) {
      throw const FormatException(
        'JCE_FIREBASE_AUTH_DOMAIN is required for production web builds.',
      );
    }
    if (requiredAppIdMarker != null &&
        !normalizedAppId.contains(requiredAppIdMarker)) {
      throw FormatException(
        'JCE_FIREBASE_APP_ID must identify a $requiredAppIdMarker application.',
      );
    }
    if (!RegExp(r'^\d+$').hasMatch(normalizedSender)) {
      throw const FormatException(
        'JCE_FIREBASE_MESSAGING_SENDER_ID must be numeric.',
      );
    }

    return FirebaseOptions(
      apiKey: normalizedApiKey,
      appId: normalizedAppId,
      messagingSenderId: normalizedSender,
      projectId: normalizedProject,
      authDomain: normalizedAuthDomain?.isEmpty == true
          ? null
          : normalizedAuthDomain,
      storageBucket: normalizedBucket,
    );
  }

  static String _required(String value, String key) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.toLowerCase().contains('replace')) {
      throw FormatException('$key is required for production.');
    }
    return normalized;
  }
}
