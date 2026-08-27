import '../remote/remote_sync_data_source.dart';

class RemoteChangeEnvelope {
  const RemoteChangeEnvelope({
    required this.change,
    required this.commandType,
    required this.actorUserId,
    required this.commandPayload,
    required this.result,
  });

  final RemoteChange change;
  final String commandType;
  final String actorUserId;
  final Map<String, Object?> commandPayload;
  final Map<String, Object?> result;

  factory RemoteChangeEnvelope.parse(RemoteChange change) {
    final root = _map(change.payload);
    if (root == null || root['schemaVersion'] != 1) {
      throw const FormatException('Unsupported remote change-feed payload.');
    }
    final commandType = root['commandType']?.toString().trim() ?? '';
    final actorUserId = root['actorUserId']?.toString().trim() ?? '';
    final payload = _map(root['commandPayload']);
    final result = _map(root['result']);
    if (commandType.isEmpty ||
        actorUserId.isEmpty ||
        payload == null ||
        result == null) {
      throw const FormatException('Remote change envelope is incomplete.');
    }
    return RemoteChangeEnvelope(
      change: change,
      commandType: commandType,
      actorUserId: actorUserId,
      commandPayload: payload,
      result: result,
    );
  }
}

Map<String, Object?>? _map(Object? value) {
  if (value is! Map) return null;
  return value.map((key, item) => MapEntry(key.toString(), item));
}
