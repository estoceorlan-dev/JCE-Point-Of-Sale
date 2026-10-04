import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/config/app_environment.dart';
import 'package:jce_pos/core/config/production_platform_policy.dart';

void main() {
  group('ProductionPlatformPolicy', () {
    test('allows the full POS in Android production', () {
      final policy = ProductionPlatformPolicy.forEnvironment(
        environment: AppEnvironment.production,
        platform: AppClientPlatform.android,
      );

      expect(policy.isSupported, isTrue);
      expect(policy.allowsPointOfSale, isTrue);
      expect(policy.ensureSupported, returnsNormally);
    });

    test('limits production web to the administration fallback', () {
      final policy = ProductionPlatformPolicy.forEnvironment(
        environment: AppEnvironment.production,
        platform: AppClientPlatform.web,
      );

      expect(policy.isSupported, isTrue);
      expect(policy.allowsPointOfSale, isFalse);
    });

    test('fails closed for Windows production', () {
      final policy = ProductionPlatformPolicy.forEnvironment(
        environment: AppEnvironment.production,
        platform: AppClientPlatform.windows,
      );

      expect(policy.isSupported, isFalse);
      expect(policy.ensureSupported, throwsUnsupportedError);
    });

    test('does not block Windows staging validation', () {
      final policy = ProductionPlatformPolicy.forEnvironment(
        environment: AppEnvironment.staging,
        platform: AppClientPlatform.windows,
      );

      expect(policy.isSupported, isTrue);
      expect(policy.allowsPointOfSale, isTrue);
    });
  });
}
