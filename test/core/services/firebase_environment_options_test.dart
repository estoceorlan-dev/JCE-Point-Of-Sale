import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/config/app_environment.dart';
import 'package:jce_pos/core/services/firebase_environment_options.dart';

void main() {
  test('development and staging select isolated Firebase projects', () {
    expect(
      FirebaseEnvironmentOptions.forEnvironment(
        AppEnvironment.development,
      ).projectId,
      'jce-pos',
    );
    expect(
      FirebaseEnvironmentOptions.forEnvironment(
        AppEnvironment.staging,
      ).projectId,
      'jce-pos-staging-259528',
    );
  });

  test('production accepts only an explicitly isolated project', () {
    const production = FirebaseOptions(
      apiKey: 'production-api-key',
      appId: '1:123:android:production',
      messagingSenderId: '123',
      projectId: 'jce-pos-production-example',
    );

    expect(
      FirebaseEnvironmentOptions.forEnvironment(
        AppEnvironment.production,
        productionOptions: production,
      ).projectId,
      production.projectId,
    );
  });

  test('production rejects a staging project even when injected', () {
    const staging = FirebaseOptions(
      apiKey: 'staging-api-key',
      appId: '1:123:android:staging',
      messagingSenderId: '123',
      projectId: 'jce-pos-staging-259528',
    );

    expect(
      () => FirebaseEnvironmentOptions.forEnvironment(
        AppEnvironment.production,
        productionOptions: staging,
      ),
      throwsStateError,
    );
  });

  test(
    'production rejects a project without an explicit production boundary',
    () {
      expect(
        () => FirebaseEnvironmentOptions.forEnvironment(
          AppEnvironment.production,
          productionOptions: const FirebaseOptions(
            apiKey: 'test-key',
            appId: 'test-app',
            messagingSenderId: '123',
            projectId: 'jce-pos-other',
          ),
        ),
        throwsStateError,
      );
    },
  );
}
