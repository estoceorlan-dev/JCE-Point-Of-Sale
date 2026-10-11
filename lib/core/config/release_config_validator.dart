import 'dart:convert';

enum ReleasePlatform {
  android,
  web,
  windows;

  static ReleasePlatform parse(String value) =>
      switch (value.trim().toLowerCase()) {
        'android' => ReleasePlatform.android,
        'web' => ReleasePlatform.web,
        'windows' => ReleasePlatform.windows,
        _ => throw const FormatException('Unsupported release platform.'),
      };
}

/// Validates public client settings. Deployment approval is supplied separately.
abstract final class ReleaseConfigValidator {
  static const requiredKeys = <String>{
    'JCE_ENV',
    'JCE_ENABLE_DEMO_AUTH',
    'JCE_ENABLE_DIAGNOSTICS',
    'JCE_API_BASE_URL',
    'JCE_DEPLOYMENT_ID',
    'JCE_ORGANIZATION_CODE',
    'JCE_OFFLINE_VERIFICATION_KEYS',
  };
  static const allowedKeys = <String>{
    ...requiredKeys,
    'JCE_BACKEND',
    'JCE_TLS_CA_CERT_BASE64',
    'JCE_ALLOW_HTTP_LOOPBACK',
    'JCE_ACCESS_REFRESH_MINUTES',
    'JCE_MAX_OFFLINE_ACCESS_HOURS',
  };
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static List<String> validate({
    required Map<String, Object?> values,
    required ReleasePlatform platform,
    required String expectedDeploymentId,
  }) {
    final errors = <String>[];
    if (!_uuid.hasMatch(expectedDeploymentId)) {
      errors.add(
        'An independently approved production deployment UUID is required.',
      );
    }
    if (values.keys.any((key) => !allowedKeys.contains(key))) {
      errors.add('Only documented public Node client settings are allowed.');
    }
    for (final key in requiredKeys) {
      if (_value(values, key) == null) errors.add('$key is required.');
    }
    if (_value(values, 'JCE_ENV') != 'production') {
      errors.add('JCE_ENV must be production.');
    }
    for (final key in ['JCE_ENABLE_DEMO_AUTH', 'JCE_ENABLE_DIAGNOSTICS']) {
      if (_value(values, key) != 'false') {
        errors.add('$key must be explicitly false.');
      }
    }
    if (values.containsKey('JCE_BACKEND') && values['JCE_BACKEND'] != 'node') {
      errors.add('JCE_BACKEND must be node.');
    }
    if (values.containsKey('JCE_ALLOW_HTTP_LOOPBACK') &&
        values['JCE_ALLOW_HTTP_LOOPBACK'] != 'false') {
      errors.add('JCE_ALLOW_HTTP_LOOPBACK must be false in production.');
    }
    if (platform == ReleasePlatform.windows) {
      errors.add(
        'Windows production remains deferred by ADR-0001 pending device acceptance.',
      );
    }
    final deployment = _value(values, 'JCE_DEPLOYMENT_ID');
    if (deployment == null ||
        !_uuid.hasMatch(deployment) ||
        deployment != expectedDeploymentId) {
      errors.add(
        'JCE_DEPLOYMENT_ID must match the approved production deployment UUID.',
      );
    }
    final origin = Uri.tryParse(_value(values, 'JCE_API_BASE_URL') ?? '');
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      errors.add(
        'JCE_API_BASE_URL must be an HTTPS origin without credentials, path, query or fragment.',
      );
    }
    if (!_validPublicKeys(_value(values, 'JCE_OFFLINE_VERIFICATION_KEYS'))) {
      errors.add(
        'JCE_OFFLINE_VERIFICATION_KEYS must contain pinned public P-256 JWKs only.',
      );
    }
    return errors;
  }

  static void ensureValid({
    required Map<String, Object?> values,
    required ReleasePlatform platform,
    required String expectedDeploymentId,
  }) {
    final errors = validate(
      values: values,
      platform: platform,
      expectedDeploymentId: expectedDeploymentId,
    );
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
  }

  static bool _validPublicKeys(String? source) {
    if (source == null) return false;
    try {
      final keys = jsonDecode(source);
      if (keys is! Map || keys.isEmpty) return false;
      for (final entry in keys.entries) {
        final key = entry.value;
        if (entry.key is! String ||
            (entry.key as String).trim().isEmpty ||
            key is! Map ||
            key['kid'] != entry.key ||
            key['kty'] != 'EC' ||
            key['crv'] != 'P-256' ||
            key.keys.any(
              (name) =>
                  !{'kid', 'kty', 'crv', 'x', 'y', 'alg', 'use'}.contains(name),
            ) ||
            (key.containsKey('alg') && key['alg'] != 'ES256') ||
            (key.containsKey('use') && key['use'] != 'sig')) {
          return false;
        }
        for (final coordinate in ['x', 'y']) {
          final value = key[coordinate];
          if (value is! String ||
              !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value) ||
              base64Url.decode(base64Url.normalize(value)).length != 32) {
            return false;
          }
        }
      }
      return true;
    } on FormatException {
      return false;
    }
  }

  static String? _value(Map<String, Object?> values, String key) {
    final value = values[key];
    if (value is! String) return null;
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.toLowerCase().contains('replace')) {
      return null;
    }
    return normalized;
  }
}
