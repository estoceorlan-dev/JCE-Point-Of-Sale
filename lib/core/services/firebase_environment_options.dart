import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../../firebase_options_staging.dart';
import '../config/app_environment.dart';

abstract final class FirebaseEnvironmentOptions {
  static FirebaseOptions forEnvironment(AppEnvironment environment) {
    return switch (environment) {
      AppEnvironment.development => DefaultFirebaseOptions.currentPlatform,
      AppEnvironment.staging => StagingFirebaseOptions.currentPlatform,
      AppEnvironment.production => throw StateError(
        'Production Firebase is not configured. Provision the isolated '
        'production backend and client apps before creating a production build.',
      ),
    };
  }
}
