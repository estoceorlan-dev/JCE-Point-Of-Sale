import '../sync/node_device_transport.dart';
import 'remote_sync_data_source.dart';

class NodeSyncDataSource
    implements RemoteSyncDataSource, PaginatedRemoteSyncDataSource {
  const NodeSyncDataSource(this.transport);
  final NodeDeviceTransport transport;
  @override
  Future<List<RemoteChange>> pullChanges({
    required String organizationId,
    required String branchId,
    required int afterSequence,
    int limit = 100,
  }) async => (await pullChangePage(
    organizationId: organizationId,
    branchId: branchId,
    afterSequence: afterSequence,
    limit: limit,
  )).changes;
  @override
  Future<RemoteChangePage> pullChangePage({
    required String organizationId,
    required String branchId,
    required int afterSequence,
    int limit = 100,
  }) async {
    final path = Uri(
      path: '/v1/sync/changes',
      queryParameters: {
        'branchId': branchId,
        'afterSequence': '$afterSequence',
        'limit': '$limit',
        'projection': 'pos',
      },
    ).toString();
    final value = await transport.sessions.authenticated(
      path,
      method: 'GET',
      syncRequest: true,
    );
    if (value['schemaVersion'] != 2 ||
        value['organizationId'] != organizationId ||
        value['branchId'] != branchId ||
        (value['nextCursor'] as int) < afterSequence) {
      throw const FormatException('Change feed scope or cursor mismatch.');
    }
    return RemoteChangePage(
      changes: (value['changes'] as List)
          .cast<Map>()
          .map(
            (row) => RemoteChange(
              sequence: row['sequence'] as int,
              organizationId: row['organizationId'] as String,
              branchId: row['branchId'] as String?,
              aggregateType: row['aggregateType'] as String,
              aggregateId: row['aggregateId'] as String,
              operationId: row['operationId'] as String,
              changeType: row['changeType'] as String,
              version: row['version'] as int,
              payload: row['payload'],
              occurredAt: DateTime.parse(row['occurredAt'] as String).toUtc(),
            ),
          )
          .toList(),
      nextCursor: value['nextCursor'] as int,
      hasMore: value['hasMore'] == true,
      permissionDigest: value['permissionDigest'] as String?,
    );
  }

  @override
  Future<ProcessedRemoteOperation?> getProcessedOperation({
    required String organizationId,
    required String branchId,
    required String operationId,
  }) async {
    final result = await transport.request(
      '/v1/sync/operations/${Uri.encodeComponent(operationId)}',
      method: 'GET',
    );
    final row = result['operation'] as Map?;
    if (row == null) return null;
    if (row['organizationId'] != organizationId ||
        row['branchId'] != branchId ||
        row['operationId'] != operationId) {
      throw const FormatException('Operation scope mismatch.');
    }
    return ProcessedRemoteOperation(
      organizationId: organizationId,
      branchId: branchId,
      operationId: operationId,
      commandType: row['commandType'] as String,
      aggregateType: row['aggregateType'] as String,
      aggregateId: row['aggregateId'] as String,
      result: row['result'],
      processedAt: DateTime.parse(row['processedAt'] as String).toUtc(),
    );
  }
}
