import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/config/release_config_validator.dart';

void main() {
  const deployment = '79927ed9-a7c6-4e4e-ab22-b0155f7e3017';
  Map<String, Object?> validConfig() => {
    'JCE_ENV': 'production',
    'JCE_ENABLE_DEMO_AUTH': 'false',
    'JCE_ENABLE_DIAGNOSTICS': 'false',
    'JCE_BACKEND': 'node',
    'JCE_API_BASE_URL': 'https://pos.example.test',
    'JCE_DEPLOYMENT_ID': deployment,
    'JCE_ORGANIZATION_CODE': 'test-org',
    'JCE_OFFLINE_VERIFICATION_KEYS': jsonEncode({
      'test-key': {
        'kid': 'test-key',
        'kty': 'EC',
        'crv': 'P-256',
        'x': base64UrlEncode(List.filled(32, 1)).replaceAll('=', ''),
        'y': base64UrlEncode(List.filled(32, 2)).replaceAll('=', ''),
      },
    }),
  };
  List<String> validate(
    Map<String, Object?> config, {
    ReleasePlatform platform = ReleasePlatform.android,
    String expected = deployment,
  }) => ReleaseConfigValidator.validate(
    values: config,
    platform: platform,
    expectedDeploymentId: expected,
  );

  test('accepts public Node Android and web profiles', () {
    expect(validate(validConfig()), isEmpty);
    expect(validate(validConfig(), platform: ReleasePlatform.web), isEmpty);
  });
  test('retains Windows production gate', () {
    expect(
      validate(validConfig(), platform: ReleasePlatform.windows).single,
      contains('Windows production'),
    );
  });
  test('requires independent approval and matching deployment', () {
    expect(validate(validConfig(), expected: ''), isNotEmpty);
    expect(
      validate(validConfig(), expected: 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa'),
      isNotEmpty,
    );
    expect(
      validate(
        validConfig()..['JCE_APPROVED_PRODUCTION_DEPLOYMENT_ID'] = deployment,
      ),
      isNotEmpty,
    );
  });
  test('rejects legacy settings and server secrets without echoing values', () {
    for (final key in ['JCE_FIREBASE_API_KEY', 'DATABASE_URL', 'PRIVATE_KEY']) {
      final errors = validate(validConfig()..[key] = 'secret-marker');
      expect(errors, isNotEmpty);
      expect(errors.join(), isNot(contains('secret-marker')));
    }
    expect(validate(validConfig()..['JCE_BACKEND'] = 'firebase'), isNotEmpty);
  });
  test('rejects unsafe production flags', () {
    for (final entry in {
      'JCE_ENV': 'staging',
      'JCE_ENABLE_DEMO_AUTH': 'true',
      'JCE_ENABLE_DIAGNOSTICS': 'true',
      'JCE_ALLOW_HTTP_LOOPBACK': 'true',
    }.entries) {
      expect(validate(validConfig()..[entry.key] = entry.value), isNotEmpty);
    }
  });
  test('requires HTTPS origin without credentials or URL suffixes', () {
    for (final origin in [
      'http://pos.test',
      '/api',
      'https://u:p@pos.test',
      'https://pos.test/api',
      'https://pos.test?x=1',
      'https://pos.test#x',
    ]) {
      expect(
        validate(validConfig()..['JCE_API_BASE_URL'] = origin),
        isNotEmpty,
      );
    }
  });
  test('rejects absent placeholders malformed keys and private material', () {
    for (final source in ['', '{}', '[]', '{bad', 'REPLACE_WITH_PUBLIC_KEYS']) {
      expect(
        validate(validConfig()..['JCE_OFFLINE_VERIFICATION_KEYS'] = source),
        isNotEmpty,
      );
    }
    for (final mutation in [
      {'d': 'private-material'},
      {'kid': 'other'},
      {'x': 'short'},
      {'kty': 'RSA'},
    ]) {
      final config = validConfig();
      final keys =
          jsonDecode(config['JCE_OFFLINE_VERIFICATION_KEYS'] as String) as Map;
      (keys['test-key'] as Map).addAll(mutation);
      expect(
        validate(config..['JCE_OFFLINE_VERIFICATION_KEYS'] = jsonEncode(keys)),
        isNotEmpty,
      );
    }
    for (final key in ReleaseConfigValidator.requiredKeys) {
      expect(validate(validConfig()..remove(key)), isNotEmpty);
    }
  });
}
