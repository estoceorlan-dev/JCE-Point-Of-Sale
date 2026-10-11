import '../database/app_database.dart';

abstract interface class RemoteCommandDataSource {
  Future<RemoteCommandResult> execute(
    SyncOutboxEntry command, {
    Map<String, Object?>? payloadOverride,
  });
}

class RemoteCommandResult {
  const RemoteCommandResult({
    required this.operationId,
    required this.duplicate,
    required this.result,
  });

  final String operationId;
  final bool duplicate;
  final Map<String, Object?> result;
}
