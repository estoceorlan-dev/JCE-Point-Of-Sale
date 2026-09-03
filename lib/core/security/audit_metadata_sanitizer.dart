const _redactedValue = '[REDACTED]';

Map<String, Object?> sanitizeAuditMetadata(Map<String, Object?> metadata) {
  return _sanitizeMap(metadata, 0);
}

Map<String, Object?> _sanitizeMap(Map<String, Object?> value, int depth) {
  if (depth >= 6) return const {'truncated': true};
  return {
    for (final entry in value.entries)
      entry.key: _isSensitiveKey(entry.key)
          ? _redactedValue
          : _sanitizeValue(entry.value, depth + 1),
  };
}

Object? _sanitizeValue(Object? value, int depth) {
  if (value == null || value is bool || value is num) return value;
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is String) {
    return value.length <= 500 ? value : '${value.substring(0, 500)}…';
  }
  if (value is Map) {
    return _sanitizeMap(
      value.map((key, item) => MapEntry(key.toString(), item)),
      depth,
    );
  }
  if (value is Iterable) {
    return value
        .take(100)
        .map((item) => _sanitizeValue(item, depth + 1))
        .toList();
  }
  return value.toString();
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  return const [
    'password',
    'passwd',
    'secret',
    'token',
    'credential',
    'authorization',
    'cardnumber',
    'pan',
    'cvv',
    'cvc',
    'pin',
  ].any(normalized.contains);
}
