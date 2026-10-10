import 'dart:convert';
import '../database/app_database.dart';
import '../sync/canonical_json.dart';
import '../sync/node_device_transport.dart';
import 'remote_api_exception.dart';
import 'remote_command_data_source.dart';

class NodeCommandDataSource implements RemoteCommandDataSource {
  const NodeCommandDataSource(this.transport);
  final NodeDeviceTransport transport;
  Future<void> checkReachability() async {
    final meta = await transport.sessions.api.request(
      '/v1/meta',
      method: 'GET',
    );
    if (meta['deploymentId'] != transport.installation.records.deploymentId) {
      throw const RemoteApiException(
        'permission-denied',
        message: 'Deployment mismatch.',
      );
    }
  }

  @override
  Future<RemoteCommandResult> execute(
    SyncOutboxEntry command, {
    Map<String, Object?>? payloadOverride,
  }) async {
    if (command.evidenceJson == null) {
      throw const RemoteApiException(
        'permission-denied',
        message:
            'This operation has no original actor evidence. Reconcile it without changing its owner.',
      );
    }
    final evidence = jsonDecode(command.evidenceJson!) as Map;
    if (evidence['deploymentId'] !=
        transport.installation.records.deploymentId) {
      throw const RemoteApiException(
        'permission-denied',
        message: 'This queue belongs to another deployment.',
      );
    }
    final body = Map<String, dynamic>.from(evidence['body'] as Map);
    if (body['operationId'] != command.operationId ||
        body['organizationId'] != command.organizationId ||
        body['branchId'] != command.branchId ||
        body['commandType'] != command.commandType ||
        body['aggregateType'] != command.aggregateType ||
        body['aggregateId'] != command.aggregateId ||
        jsonDigest(body['payload']) !=
            jsonDigest(jsonDecode(command.payloadJson))) {
      throw const RemoteApiException(
        'permission-denied',
        message: 'The queued operation changed after it was signed.',
      );
    }
    final result = await transport.request('/v1/sync/commands', body: body);
    return RemoteCommandResult(
      operationId: result['operationId'] as String,
      duplicate: result['duplicate'] == true,
      result: Map<String, Object?>.from(result['result'] as Map),
    );
  }
}
