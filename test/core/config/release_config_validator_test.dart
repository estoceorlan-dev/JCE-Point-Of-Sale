import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/config/release_config_validator.dart';

void main() {
  const projectId = 'jce-pos-production-example';

  Map<String, Object?> validConfig({String appKind = 'android'}) => {
    'JCE_ENV': 'production',
    'JCE_ENABLE_DEMO_AUTH': 'false',
    'JCE_ENABLE_DIAGNOSTICS': 'false',
    'JCE_FIREBASE_FUNCTIONS_REGION': 'asia-southeast1',
    'JCE_FIREBASE_API_KEY': 'production-api-key',
    'JCE_FIREBASE_APP_ID': '1:123:$appKind:production',
    'JCE_FIREBASE_MESSAGING_SENDER_ID': '123',
    'JCE_FIREBASE_PROJECT_ID': projectId,
    'JCE_FIREBASE_STORAGE_BUCKET': '$projectId.firebasestorage.app',
  };

  test('accepts an isolated Android production configuration', () {
    expect(
      ReleaseConfigValidator.validate(
        values: validConfig(),
        platform: ReleasePlatform.android,
        expectedProjectId: projectId,
      ),
      isEmpty,
    );
  });

  test('requires the web Auth domain', () {
    final errors = ReleaseConfigValidator.validate(
      values: validConfig(appKind: 'web'),
      platform: ReleasePlatform.web,
      expectedProjectId: projectId,
    );

    expect(errors, contains('JCE_FIREBASE_AUTH_DOMAIN is required for web.'));
  });

  test('rejects environment confusion and unsafe production flags', () {
    final config = validConfig()
      ..['JCE_ENV'] = 'staging'
      ..['JCE_ENABLE_DEMO_AUTH'] = 'true'
      ..['JCE_ENABLE_DIAGNOSTICS'] = 'true'
      ..['JCE_DEMO_BRANCH_ID'] = 'branch-1'
      ..['JCE_FIREBASE_PROJECT_ID'] = 'jce-pos-staging-259528';

    final errors = ReleaseConfigValidator.validate(
      values: config,
      platform: ReleasePlatform.android,
      expectedProjectId: projectId,
    );

    expect(errors, contains('JCE_ENV must be production.'));
    expect(errors, contains('JCE_ENABLE_DEMO_AUTH must be explicitly false.'));
    expect(
      errors,
      contains('JCE_ENABLE_DIAGNOSTICS must be explicitly false.'),
    );
    expect(
      errors,
      contains('JCE_DEMO_BRANCH_ID must not be present in production.'),
    );
    expect(
      errors,
      contains('A non-production Firebase project cannot be released.'),
    );
  });

  test('fails Windows validation until ADR-0001 is superseded', () {
    final errors = ReleaseConfigValidator.validate(
      values: validConfig(appKind: 'web'),
      platform: ReleasePlatform.windows,
      expectedProjectId: projectId,
    );

    expect(errors.single, contains('Windows production is deferred'));
  });

  test('keeps the independently approved project outside the config file', () {
    final config = validConfig()
      ..['JCE_APPROVED_PRODUCTION_PROJECT_ID'] = projectId;

    final errors = ReleaseConfigValidator.validate(
      values: config,
      platform: ReleasePlatform.android,
      expectedProjectId: projectId,
    );

    expect(
      errors,
      contains(
        'JCE_APPROVED_PRODUCTION_PROJECT_ID must be supplied separately by CI.',
      ),
    );
  });

  test('rejects a project ID that is not explicitly production', () {
    final config = validConfig()..['JCE_FIREBASE_PROJECT_ID'] = 'jce-pos-other';

    final errors = ReleaseConfigValidator.validate(
      values: config,
      platform: ReleasePlatform.android,
      expectedProjectId: 'jce-pos-other',
    );

    expect(
      errors,
      contains('A non-production Firebase project cannot be released.'),
    );
  });
}
