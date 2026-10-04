import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../../firebase_options_production.dart';
import '../../firebase_options_staging.dart';
import '../config/app_environment.dart';

abstract final class FirebaseEnvironmentOptions {
  static FirebaseOptions forEnvironment(
    AppEnvironment environment, {
    FirebaseOptions? productionOptions,
  }) {
    return switch (environment) {
      AppEnvironment.development => DefaultFirebaseOptions.currentPlatform,
      AppEnvironment.staging => StagingFirebaseOptions.currentPlatform,
      AppEnvironment.production => _validateProduction(
        productionOptions ?? ProductionFirebaseOptions.currentPlatform,
      ),
    };
  }

  static FirebaseOptions _validateProduction(FirebaseOptions options) {
    if (options.projectId == 'jce-pos' ||
        options.projectId == 'jce-pos-staging-259528' ||
        options.projectId.contains('development') ||
        options.projectId.contains('staging') ||
        !options.projectId.contains('production')) {
      throw StateError(
        'Production cannot initialize the ${options.projectId} Firebase project.',
      );
    }
    return options;
  }
}
