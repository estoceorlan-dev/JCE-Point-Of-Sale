import 'generated/pos_connector.dart';

abstract interface class RemoteSyncDataSource {
  Future<List<RemoteChange>> pullChanges({
    required String organizationId,
    required String branchId,
    required int afterSequence,
    int limit = 100,
  });

  Future<ProcessedRemoteOperation?> getProcessedOperation({
    required String organizationId,
    required String branchId,
    required String operationId,
  });
}

final class SqlConnectRemoteSyncDataSource implements RemoteSyncDataSource {
  SqlConnectRemoteSyncDataSource({PosConnectorConnector? connector})
    : _connector = connector ?? PosConnectorConnector.instance;

  final PosConnectorConnector _connector;

  @override
  Future<List<RemoteChange>> pullChanges({
    required String organizationId,
    required String branchId,
    required int afterSequence,
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 500) {
      throw RangeError.range(limit, 1, 500, 'limit');
    }
    final response = await _connector
        .pullChanges(
          organizationId: organizationId,
          branchId: branchId,
          afterSequence: afterSequence,
          limit: limit,
        )
        .execute();
    return response.data.changes
        .map(
          (change) => RemoteChange(
            sequence: change.sequence,
            organizationId: change.organizationId,
            branchId: change.branchId,
            aggregateType: change.aggregateType,
            aggregateId: change.aggregateId,
            operationId: change.operationId,
            changeType: change.changeType,
            version: change.version,
            payload: change.payloadJson.toJson(),
            occurredAt: change.occurredAt.toDateTime().toUtc(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<ProcessedRemoteOperation?> getProcessedOperation({
    required String organizationId,
    required String branchId,
    required String operationId,
  }) async {
    final response = await _connector
        .getProcessedOperation(
          organizationId: organizationId,
          branchId: branchId,
          operationId: operationId,
        )
        .execute();
    final operations = response.data.operations;
    if (operations.isEmpty) {
      return null;
    }
    final operation = operations.single;
    return ProcessedRemoteOperation(
      organizationId: operation.organizationId,
      operationId: operation.operationId,
      branchId: operation.branchId,
      commandType: operation.commandType,
      aggregateType: operation.aggregateType,
      aggregateId: operation.aggregateId,
      result: operation.resultJson.toJson(),
      processedAt: operation.processedAt.toDateTime().toUtc(),
    );
  }
}

class RemoteChange {
  const RemoteChange({
    required this.sequence,
    required this.organizationId,
    required this.branchId,
    required this.aggregateType,
    required this.aggregateId,
    required this.operationId,
    required this.changeType,
    required this.version,
    required this.payload,
    required this.occurredAt,
  });

  final int sequence;
  final String organizationId;
  final String? branchId;
  final String aggregateType;
  final String aggregateId;
  final String operationId;
  final String changeType;
  final int version;
  final Object? payload;
  final DateTime occurredAt;
}

class ProcessedRemoteOperation {
  const ProcessedRemoteOperation({
    required this.organizationId,
    required this.operationId,
    required this.branchId,
    required this.commandType,
    required this.aggregateType,
    required this.aggregateId,
    required this.result,
    required this.processedAt,
  });

  final String organizationId;
  final String operationId;
  final String? branchId;
  final String commandType;
  final String aggregateType;
  final String aggregateId;
  final Object? result;
  final DateTime processedAt;
}
