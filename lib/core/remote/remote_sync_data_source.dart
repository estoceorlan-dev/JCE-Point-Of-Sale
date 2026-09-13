import 'generated/pos_connector.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

abstract interface class PaginatedRemoteSyncDataSource {
  Future<RemoteChangePage> pullChangePage({
    required String organizationId,
    required String branchId,
    required int afterSequence,
    int limit = 100,
  });
}

class RemoteChangePage {
  const RemoteChangePage({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
    this.permissionDigest,
  });

  final List<RemoteChange> changes;
  final int nextCursor;
  final bool hasMore;
  final String? permissionDigest;
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

final class CloudFunctionsAuthorizedRemoteSyncDataSource
    implements RemoteSyncDataSource, PaginatedRemoteSyncDataSource {
  CloudFunctionsAuthorizedRemoteSyncDataSource({
    required FirebaseFunctions functions,
    required String functionName,
    RemoteSyncDataSource? processedOperationFallback,
  }) : _functions = functions,
       _functionName = functionName,
       _processedOperationFallback =
           processedOperationFallback ?? SqlConnectRemoteSyncDataSource();

  final FirebaseFunctions _functions;
  final String _functionName;
  final RemoteSyncDataSource _processedOperationFallback;

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
    final response = await _functions.httpsCallable(_functionName).call({
      'organizationId': organizationId,
      'branchId': branchId,
      'afterSequence': afterSequence,
      'limit': limit,
      'projection': 'pos',
    });
    if (response.data is! Map) {
      throw const FormatException('Invalid authorized change response.');
    }
    final value = Map<String, Object?>.from(response.data as Map);
    if (value['schemaVersion'] != 2 ||
        value['organizationId'] != organizationId ||
        value['branchId'] != branchId ||
        value['changes'] is! List) {
      throw const FormatException('Authorized changes are outside this scope.');
    }
    final changes = (value['changes'] as List)
        .map((raw) {
          final row = Map<String, Object?>.from(raw as Map);
          return RemoteChange(
            sequence: (row['sequence'] as num).toInt(),
            organizationId: row['organizationId'] as String,
            branchId: row['branchId'] as String?,
            aggregateType: row['aggregateType'] as String,
            aggregateId: row['aggregateId'] as String,
            operationId: row['operationId'] as String,
            changeType: row['changeType'] as String,
            version: (row['version'] as num).toInt(),
            payload: row['payload'],
            occurredAt: DateTime.parse(row['occurredAt'] as String).toUtc(),
          );
        })
        .toList(growable: false);
    final nextCursor = (value['nextCursor'] as num?)?.toInt();
    if (nextCursor == null || nextCursor < afterSequence) {
      throw const FormatException('Authorized change cursor moved backwards.');
    }
    return RemoteChangePage(
      changes: changes,
      nextCursor: nextCursor,
      hasMore: value['hasMore'] == true,
      permissionDigest: value['permissionDigest'] as String?,
    );
  }

  @override
  Future<ProcessedRemoteOperation?> getProcessedOperation({
    required String organizationId,
    required String branchId,
    required String operationId,
  }) => _processedOperationFallback.getProcessedOperation(
    organizationId: organizationId,
    branchId: branchId,
    operationId: operationId,
  );
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
