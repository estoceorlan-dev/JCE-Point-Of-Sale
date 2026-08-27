part of 'pos_connector.dart';

class GetProcessedOperationVariablesBuilder {
  String organizationId;
  String branchId;
  String operationId;

  final FirebaseDataConnect _dataConnect;
  GetProcessedOperationVariablesBuilder(
    this._dataConnect, {
    required this.organizationId,
    required this.branchId,
    required this.operationId,
  });
  Deserializer<GetProcessedOperationData> dataDeserializer = (dynamic json) =>
      GetProcessedOperationData.fromJson(jsonDecode(json));
  Serializer<GetProcessedOperationVariables> varsSerializer =
      (GetProcessedOperationVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<GetProcessedOperationData, GetProcessedOperationVariables>>
  execute() {
    return ref().execute();
  }

  QueryRef<GetProcessedOperationData, GetProcessedOperationVariables> ref() {
    GetProcessedOperationVariables vars = GetProcessedOperationVariables(
      organizationId: organizationId,
      branchId: branchId,
      operationId: operationId,
    );
    return _dataConnect.query(
      "GetProcessedOperation",
      dataDeserializer,
      varsSerializer,
      vars,
    );
  }
}

@immutable
class GetProcessedOperationOperations {
  final String organizationId;
  final String operationId;
  final String? branchId;
  final String commandType;
  final String aggregateType;
  final String aggregateId;
  final AnyValue resultJson;
  final Timestamp processedAt;
  GetProcessedOperationOperations.fromJson(dynamic json)
    : organizationId = nativeFromJson<String>(json['organizationId']),
      operationId = nativeFromJson<String>(json['operationId']),
      branchId = json['branchId'] == null
          ? null
          : nativeFromJson<String>(json['branchId']),
      commandType = nativeFromJson<String>(json['commandType']),
      aggregateType = nativeFromJson<String>(json['aggregateType']),
      aggregateId = nativeFromJson<String>(json['aggregateId']),
      resultJson = AnyValue.fromJson(json['resultJson']),
      processedAt = Timestamp.fromJson(json['processedAt']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final GetProcessedOperationOperations otherTyped =
        other as GetProcessedOperationOperations;
    return organizationId == otherTyped.organizationId &&
        operationId == otherTyped.operationId &&
        branchId == otherTyped.branchId &&
        commandType == otherTyped.commandType &&
        aggregateType == otherTyped.aggregateType &&
        aggregateId == otherTyped.aggregateId &&
        resultJson == otherTyped.resultJson &&
        processedAt == otherTyped.processedAt;
  }

  @override
  int get hashCode => Object.hashAll([
    organizationId.hashCode,
    operationId.hashCode,
    branchId.hashCode,
    commandType.hashCode,
    aggregateType.hashCode,
    aggregateId.hashCode,
    resultJson.hashCode,
    processedAt.hashCode,
  ]);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['organizationId'] = nativeToJson<String>(organizationId);
    json['operationId'] = nativeToJson<String>(operationId);
    if (branchId != null) {
      json['branchId'] = nativeToJson<String?>(branchId);
    }
    json['commandType'] = nativeToJson<String>(commandType);
    json['aggregateType'] = nativeToJson<String>(aggregateType);
    json['aggregateId'] = nativeToJson<String>(aggregateId);
    json['resultJson'] = resultJson.toJson();
    json['processedAt'] = processedAt.toJson();
    return json;
  }

  GetProcessedOperationOperations({
    required this.organizationId,
    required this.operationId,
    this.branchId,
    required this.commandType,
    required this.aggregateType,
    required this.aggregateId,
    required this.resultJson,
    required this.processedAt,
  });
}

@immutable
class GetProcessedOperationData {
  final List<GetProcessedOperationOperations> operations;
  GetProcessedOperationData.fromJson(dynamic json)
    : operations = (json['operations'] as List<dynamic>)
          .map((e) => GetProcessedOperationOperations.fromJson(e))
          .toList();
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final GetProcessedOperationData otherTyped =
        other as GetProcessedOperationData;
    return operations == otherTyped.operations;
  }

  @override
  int get hashCode => operations.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['operations'] = operations.map((e) => e.toJson()).toList();
    return json;
  }

  GetProcessedOperationData({required this.operations});
}

@immutable
class GetProcessedOperationVariables {
  final String organizationId;
  final String branchId;
  final String operationId;
  @Deprecated(
    'fromJson is deprecated for Variable classes as they are no longer required for deserialization.',
  )
  GetProcessedOperationVariables.fromJson(Map<String, dynamic> json)
    : organizationId = nativeFromJson<String>(json['organizationId']),
      branchId = nativeFromJson<String>(json['branchId']),
      operationId = nativeFromJson<String>(json['operationId']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final GetProcessedOperationVariables otherTyped =
        other as GetProcessedOperationVariables;
    return organizationId == otherTyped.organizationId &&
        branchId == otherTyped.branchId &&
        operationId == otherTyped.operationId;
  }

  @override
  int get hashCode => Object.hashAll([
    organizationId.hashCode,
    branchId.hashCode,
    operationId.hashCode,
  ]);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['organizationId'] = nativeToJson<String>(organizationId);
    json['branchId'] = nativeToJson<String>(branchId);
    json['operationId'] = nativeToJson<String>(operationId);
    return json;
  }

  GetProcessedOperationVariables({
    required this.organizationId,
    required this.branchId,
    required this.operationId,
  });
}
