enum ReleasePlatform {
  android,
  web,
  windows;

  static ReleasePlatform parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'android' => ReleasePlatform.android,
      'web' => ReleasePlatform.web,
      'windows' => ReleasePlatform.windows,
      _ => throw FormatException('Unsupported release platform: $value'),
    };
  }
}

abstract final class ReleaseConfigValidator {
  static const requiredKeys = <String>{
    'JCE_ENV',
    'JCE_ENABLE_DEMO_AUTH',
    'JCE_ENABLE_DIAGNOSTICS',
    'JCE_FIREBASE_FUNCTIONS_REGION',
    'JCE_FIREBASE_API_KEY',
    'JCE_FIREBASE_APP_ID',
    'JCE_FIREBASE_MESSAGING_SENDER_ID',
    'JCE_FIREBASE_PROJECT_ID',
    'JCE_FIREBASE_STORAGE_BUCKET',
  };

  static List<String> validate({
    required Map<String, Object?> values,
    required ReleasePlatform platform,
    required String expectedProjectId,
  }) {
    final errors = <String>[];
    final normalizedExpectedProjectId = expectedProjectId.trim();
    if (normalizedExpectedProjectId.isEmpty) {
      errors.add('An expected production project ID is required.');
    }

    for (final key in requiredKeys) {
      if (_value(values, key) == null) errors.add('$key is required.');
    }
    if (platform == ReleasePlatform.web &&
        _value(values, 'JCE_FIREBASE_AUTH_DOMAIN') == null) {
      errors.add('JCE_FIREBASE_AUTH_DOMAIN is required for web.');
    }
    if (platform == ReleasePlatform.web &&
        _value(values, 'JCE_APP_CHECK_WEB_SITE_KEY') == null) {
      errors.add('JCE_APP_CHECK_WEB_SITE_KEY is required for web.');
    }
    if (platform == ReleasePlatform.windows) {
      errors.add(
        'Windows production is deferred by ADR-0001 until its supported '
        'transport and device-trust implementation is complete.',
      );
    }

    if (_value(values, 'JCE_ENV')?.toLowerCase() != 'production') {
      errors.add('JCE_ENV must be production.');
    }
    if (_value(values, 'JCE_ENABLE_DEMO_AUTH')?.toLowerCase() != 'false') {
      errors.add('JCE_ENABLE_DEMO_AUTH must be explicitly false.');
    }
    if (_value(values, 'JCE_ENABLE_DIAGNOSTICS')?.toLowerCase() != 'false') {
      errors.add('JCE_ENABLE_DIAGNOSTICS must be explicitly false.');
    }
    if (_value(values, 'JCE_DEMO_BRANCH_ID') != null) {
      errors.add('JCE_DEMO_BRANCH_ID must not be present in production.');
    }
    if (_value(values, 'JCE_APPROVED_PRODUCTION_PROJECT_ID') != null) {
      errors.add(
        'JCE_APPROVED_PRODUCTION_PROJECT_ID must be supplied separately by CI.',
      );
    }

    final projectId = _value(values, 'JCE_FIREBASE_PROJECT_ID');
    if (projectId != null && projectId != normalizedExpectedProjectId) {
      errors.add(
        'JCE_FIREBASE_PROJECT_ID does not match the approved production project.',
      );
    }
    if (projectId != null &&
        (projectId == 'jce-pos' ||
            projectId == 'jce-pos-staging-259528' ||
            projectId.contains('development') ||
            projectId.contains('staging') ||
            !projectId.contains('production'))) {
      errors.add('A non-production Firebase project cannot be released.');
    }

    final appId = _value(values, 'JCE_FIREBASE_APP_ID');
    final expectedAppMarker = platform == ReleasePlatform.android
        ? ':android:'
        : ':web:';
    if (appId != null && !appId.contains(expectedAppMarker)) {
      errors.add('JCE_FIREBASE_APP_ID is not registered for ${platform.name}.');
    }

    final functionsRegion = _value(values, 'JCE_FIREBASE_FUNCTIONS_REGION');
    if (functionsRegion != null &&
        !RegExp(r'^[a-z]+-[a-z]+[0-9]+$').hasMatch(functionsRegion)) {
      errors.add('JCE_FIREBASE_FUNCTIONS_REGION is invalid.');
    }

    final apiBaseUrl = _value(values, 'JCE_API_BASE_URL');
    if (apiBaseUrl != null) {
      final uri = Uri.tryParse(apiBaseUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        errors.add('JCE_API_BASE_URL must use an absolute HTTPS URL.');
      }
    }

    return errors;
  }

  static void ensureValid({
    required Map<String, Object?> values,
    required ReleasePlatform platform,
    required String expectedProjectId,
  }) {
    final errors = validate(
      values: values,
      platform: platform,
      expectedProjectId: expectedProjectId,
    );
    if (errors.isNotEmpty) {
      throw FormatException(errors.join('\n'));
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
