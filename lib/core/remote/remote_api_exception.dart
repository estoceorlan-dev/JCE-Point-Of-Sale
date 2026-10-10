/// Transport-independent command rejection. Never contains credentials or payloads.
class RemoteApiException implements Exception {
  const RemoteApiException(
    this.code, {
    this.message,
    this.details,
    this.status,
  });
  final String code;
  final String? message;
  final Object? details;
  final int? status;
  @override
  String toString() => 'RemoteApiException($code)';
}
