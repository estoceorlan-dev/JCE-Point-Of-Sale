part of 'pos_connector.dart';

class PullChangesVariablesBuilder {
  String organizationId;
  String branchId;
  int afterSequence;
  int limit;

  final FirebaseDataConnect _dataConnect;
  PullChangesVariablesBuilder(
    this._dataConnect, {
    required this.organizationId,
    required this.branchId,
    required this.afterSequence,
    required this.limit,
  });
  Deserializer<PullChangesData> dataDeserializer = (dynamic json) =>
      PullChangesData.fromJson(jsonDecode(json));
  Serializer<PullChangesVariables> varsSerializer =
      (PullChangesVariables vars) => jsonEncode(vars.toJson());
  Future<QueryResult<PullChangesData, PullChangesVariables>> execute() {
    return ref().execute();
  }

  QueryRef<PullChangesData, PullChangesVariables> ref() {
    PullChangesVariables vars = PullChangesVariables(
      organizationId: organizationId,
      branchId: branchId,
      afterSequence: afterSequence,
      limit: limit,
    );
    return _dataConnect.query(
      "PullChanges",
      dataDeserializer,
      varsSerializer,
      vars,
    );
  }
}

@immutable
class PullChangesChanges {
  final int sequence;
  final String organizationId;
  final String? branchId;
  final String aggregateType;
  final String aggregateId;
  final String operationId;
  final String changeType;
  final int version;
  final AnyValue payloadJson;
  final Timestamp occurredAt;
  PullChangesChanges.fromJson(dynamic json)
    : sequence = nativeFromJson<int>(json['sequence']),
      organizationId = nativeFromJson<String>(json['organizationId']),
      branchId = json['branchId'] == null
          ? null
          : nativeFromJson<String>(json['branchId']),
      aggregateType = nativeFromJson<String>(json['aggregateType']),
      aggregateId = nativeFromJson<String>(json['aggregateId']),
      operationId = nativeFromJson<String>(json['operationId']),
      changeType = nativeFromJson<String>(json['changeType']),
      version = nativeFromJson<int>(json['version']),
      payloadJson = AnyValue.fromJson(json['payloadJson']),
      occurredAt = Timestamp.fromJson(json['occurredAt']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final PullChangesChanges otherTyped = other as PullChangesChanges;
    return sequence == otherTyped.sequence &&
        organizationId == otherTyped.organizationId &&
        branchId == otherTyped.branchId &&
        aggregateType == otherTyped.aggregateType &&
        aggregateId == otherTyped.aggregateId &&
        operationId == otherTyped.operationId &&
        changeType == otherTyped.changeType &&
        version == otherTyped.version &&
        payloadJson == otherTyped.payloadJson &&
        occurredAt == otherTyped.occurredAt;
  }

  @override
  int get hashCode => Object.hashAll([
    sequence.hashCode,
    organizationId.hashCode,
    branchId.hashCode,
    aggregateType.hashCode,
    aggregateId.hashCode,
    operationId.hashCode,
    changeType.hashCode,
    version.hashCode,
    payloadJson.hashCode,
    occurredAt.hashCode,
  ]);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['sequence'] = nativeToJson<int>(sequence);
    json['organizationId'] = nativeToJson<String>(organizationId);
    if (branchId != null) {
      json['branchId'] = nativeToJson<String?>(branchId);
    }
    json['aggregateType'] = nativeToJson<String>(aggregateType);
    json['aggregateId'] = nativeToJson<String>(aggregateId);
    json['operationId'] = nativeToJson<String>(operationId);
    json['changeType'] = nativeToJson<String>(changeType);
    json['version'] = nativeToJson<int>(version);
    json['payloadJson'] = payloadJson.toJson();
    json['occurredAt'] = occurredAt.toJson();
    return json;
  }

  PullChangesChanges({
    required this.sequence,
    required this.organizationId,
    this.branchId,
    required this.aggregateType,
    required this.aggregateId,
    required this.operationId,
    required this.changeType,
    required this.version,
    required this.payloadJson,
    required this.occurredAt,
  });
}

@immutable
class PullChangesData {
  final List<PullChangesChanges> changes;
  PullChangesData.fromJson(dynamic json)
    : changes = (json['changes'] as List<dynamic>)
          .map((e) => PullChangesChanges.fromJson(e))
          .toList();
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final PullChangesData otherTyped = other as PullChangesData;
    return changes == otherTyped.changes;
  }

  @override
  int get hashCode => changes.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['changes'] = changes.map((e) => e.toJson()).toList();
    return json;
  }

  PullChangesData({required this.changes});
}

@immutable
class PullChangesVariables {
  final String organizationId;
  final String branchId;
  final int afterSequence;
  final int limit;
  @Deprecated(
    'fromJson is deprecated for Variable classes as they are no longer required for deserialization.',
  )
  PullChangesVariables.fromJson(Map<String, dynamic> json)
    : organizationId = nativeFromJson<String>(json['organizationId']),
      branchId = nativeFromJson<String>(json['branchId']),
      afterSequence = nativeFromJson<int>(json['afterSequence']),
      limit = nativeFromJson<int>(json['limit']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final PullChangesVariables otherTyped = other as PullChangesVariables;
    return organizationId == otherTyped.organizationId &&
        branchId == otherTyped.branchId &&
        afterSequence == otherTyped.afterSequence &&
        limit == otherTyped.limit;
  }

  @override
  int get hashCode => Object.hashAll([
    organizationId.hashCode,
    branchId.hashCode,
    afterSequence.hashCode,
    limit.hashCode,
  ]);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['organizationId'] = nativeToJson<String>(organizationId);
    json['branchId'] = nativeToJson<String>(branchId);
    json['afterSequence'] = nativeToJson<int>(afterSequence);
    json['limit'] = nativeToJson<int>(limit);
    return json;
  }

  PullChangesVariables({
    required this.organizationId,
    required this.branchId,
    required this.afterSequence,
    required this.limit,
  });
}
