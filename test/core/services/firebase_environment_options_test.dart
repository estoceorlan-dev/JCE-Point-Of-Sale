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

  test('production fails closed until its backend is provisioned', () {
    expect(
      () =>
          FirebaseEnvironmentOptions.forEnvironment(AppEnvironment.production),
      throwsStateError,
    );
  });
}
