import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Applies the same attestation policy to primary and temporary Firebase apps.
class FirebaseAppCheckInitializer {
  const FirebaseAppCheckInitializer();

  Future<void> initialize({
    required FirebaseApp app,
    required AppConfig config,
    FirebaseAppCheck? appCheck,
    bool isWeb = kIsWeb,
  }) async {
    if (!config.environment.isProduction) return;
    final webSiteKey = config.appCheckWebSiteKey?.trim();
    if (isWeb && (webSiteKey == null || webSiteKey.isEmpty)) {
      throw StateError(
        'JCE_APP_CHECK_WEB_SITE_KEY is required for production web.',
      );
    }
    final attestation = appCheck ?? FirebaseAppCheck.instanceFor(app: app);
    await attestation.activate(
      providerAndroid: const AndroidPlayIntegrityProvider(),
      providerWeb: isWeb ? ReCaptchaEnterpriseProvider(webSiteKey!) : null,
    );
    await attestation.setTokenAutoRefreshEnabled(true);
  }
}
