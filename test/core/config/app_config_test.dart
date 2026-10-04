import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/config/app_config.dart';
import 'package:jce_pos/core/config/app_environment.dart';

void main() {
  group('AppConfig', () {
    test('uses safe production defaults', () {
      final config = AppConfig.fromValues(environment: 'production');

      expect(config.environment, AppEnvironment.production);
      expect(config.enableDemoAuth, isFalse);
      expect(config.enableDiagnostics, isFalse);
      expect(config.apiBaseUri, isNull);
      expect(config.demoBranchId, isNull);
      expect(
        config.firebaseFunctionsRegion,
        AppConfig.defaultFirebaseFunctionsRegion,
      );
      expect(
        config.accessRefreshInterval,
        AppConfig.defaultAccessRefreshInterval,
      );
      expect(config.maxOfflineAccessAge, AppConfig.defaultMaxOfflineAccessAge);
    });

    test('keeps demo authentication opt-in during development', () {
      final config = AppConfig.fromValues(environment: 'development');

      expect(config.enableDemoAuth, isFalse);
      expect(config.demoBranchId, isNull);
      expect(
        config.firebaseFunctionsRegion,
        AppConfig.defaultFirebaseFunctionsRegion,
      );
    });

    test('accepts test overrides without changing dart defines', () {
      final config = AppConfig.fromValues(
        environment: 'development',
        apiBaseUrl: 'https://staging.example.test/api',
        enableDemoAuth: 'true',
        enableDiagnostics: 'true',
        demoBranchId: 'test-branch',
      );

      expect(config.environment, AppEnvironment.development);
      expect(config.apiBaseUri, Uri.parse('https://staging.example.test/api'));
      expect(config.enableDemoAuth, isTrue);
      expect(config.enableDiagnostics, isTrue);
      expect(config.demoBranchId, 'test-branch');
    });

    test('allows the Firebase Functions region to be overridden', () {
      final config = AppConfig.fromValues(
        environment: 'development',
        firebaseFunctionsRegion: 'us-central1',
      );

      expect(config.firebaseFunctionsRegion, 'us-central1');
    });

    test('allows access verification durations to be overridden', () {
      final config = AppConfig.fromValues(
        environment: 'development',
        accessRefreshMinutes: '10',
        maxOfflineAccessHours: '8',
      );

      expect(config.accessRefreshInterval, const Duration(minutes: 10));
      expect(config.maxOfflineAccessAge, const Duration(hours: 8));
    });

    test('rejects invalid access verification durations', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'development',
          accessRefreshMinutes: '0',
        ),
        throwsFormatException,
      );
    });

    test('rejects relative API endpoints', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'development',
          apiBaseUrl: '/api',
          demoBranchId: 'test-branch',
        ),
        throwsFormatException,
      );
    });

    test('rejects demo authentication outside development', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'production',
          enableDemoAuth: 'true',
          demoBranchId: 'test-branch',
        ),
        throwsFormatException,
      );
    });

    test('requires an explicit environment for protected builds', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'development',
          enforceReleaseSafety: true,
          environmentWasExplicit: false,
        ),
        throwsFormatException,
      );
    });

    test('rejects development in profile and release builds', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'development',
          enforceReleaseSafety: true,
        ),
        throwsFormatException,
      );
    });

    test('accepts an explicit staging protected build', () {
      final config = AppConfig.fromValues(
        environment: 'staging',
        enforceReleaseSafety: true,
      );

      expect(config.environment, AppEnvironment.staging);
      expect(config.enableDemoAuth, isFalse);
    });

    test('rejects production diagnostics', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'production',
          enableDiagnostics: 'true',
        ),
        throwsFormatException,
      );
    });
  });
}
