import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Shared signing format: sorted UTF-16 keys and safe integer JSON numbers.
String canonicalJson(Object? value, [int depth = 0]) {
  if (depth > 48) throw const FormatException('JSON nesting exceeds 48.');
  if (value == null || value is bool || value is String) {
    return jsonEncode(value);
  }
  if (value is int && value.abs() <= 9007199254740991) return '$value';
  if (value is List) {
    return '[${value.map((v) => canonicalJson(v, depth + 1)).join(',')}]';
  }
  if (value is Map && value.keys.every((key) => key is String)) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${canonicalJson(value[key], depth + 1)}').join(',')}}';
  }
  throw const FormatException('Signed JSON requires safe integer numbers.');
}

String jsonDigest(Object? value) =>
    sha256.convert(utf8.encode(canonicalJson(value))).toString();
