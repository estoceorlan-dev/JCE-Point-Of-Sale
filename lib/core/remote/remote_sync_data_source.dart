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
