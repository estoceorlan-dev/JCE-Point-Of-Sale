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
      expect(config.onlineOnly, isFalse);
      expect(config.apiBaseUri, isNull);
      expect(config.demoBranchId, isNull);
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

    test('rejects legacy and unknown backend profiles', () {
      for (final backend in ['firebase', 'other', '']) {
        expect(
          () => AppConfig.fromValues(environment: 'staging', backend: backend),
          throwsFormatException,
        );
      }
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

    test('online-only mode requires an API and rejects demo auth', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'production',
          onlineOnly: 'true',
        ),
        throwsFormatException,
      );
      expect(
        () => AppConfig.fromValues(
          environment: 'development',
          apiBaseUrl: 'https://pos.example.test',
          onlineOnly: 'true',
          enableDemoAuth: 'true',
          demoBranchId: 'demo',
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
