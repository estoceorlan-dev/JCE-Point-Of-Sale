import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../startup/app_initialization_service.dart';
import 'firebase_environment_options.dart';

final firebaseInitializationServiceProvider =
    Provider<AppInitializationService>((ref) {
      return const FirebaseInitializationService();
    });

class FirebaseInitializationService implements AppInitializationService {
  const FirebaseInitializationService();

  @override
  Future<void> initialize(AppConfig config) async {
    final options = FirebaseEnvironmentOptions.forEnvironment(
      config.environment,
    );
    final existingApps = Firebase.apps;
    if (existingApps.isNotEmpty) {
      final activeProjectId = existingApps.first.options.projectId;
      if (activeProjectId != options.projectId) {
        throw StateError(
          'Firebase is already initialized for $activeProjectId, but the '
          '${config.environment.name} build requires ${options.projectId}.',
        );
      }
      return;
    }

    await Firebase.initializeApp(options: options);
  }
}
