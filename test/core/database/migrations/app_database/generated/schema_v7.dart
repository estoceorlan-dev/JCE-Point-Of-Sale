// dart format width=80
import 'package:drift/src/runtime/query_builder/query_builder.dart' as i2;
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class LocalMetadata extends Table
    with TableInfo<LocalMetadata, LocalMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LocalMetadata(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_metadata';
  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMetadataData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  LocalMetadata createAlias(String alias) {
    return LocalMetadata(attachedDatabase, alias);
  }
}

class LocalMetadataData extends DataClass
    implements Insertable<LocalMetadataData> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const LocalMetadataData({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalMetadataCompanion toCompanion(bool nullToAbsent) {
    return LocalMetadataCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalMetadataData copyWith({
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => LocalMetadataData(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalMetadataData copyWithCompanion(LocalMetadataCompanion data) {
    return LocalMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMetadataData &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class LocalMetadataCompanion extends UpdateCompanion<LocalMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMetadataCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<LocalMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncOutbox extends Table with TableInfo<SyncOutbox, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncOutbox(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> actorUserId = GeneratedColumn<String>(
    'actor_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> commandType = GeneratedColumn<String>(
    'command_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> aggregateType = GeneratedColumn<String>(
    'aggregate_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> aggregateId = GeneratedColumn<String>(
    'aggregate_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    organizationId,
    branchId,
    actorUserId,
    commandType,
    aggregateType,
    aggregateId,
    payloadJson,
    status,
    attemptCount,
    nextAttemptAt,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      ),
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      ),
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_id'],
      ),
      commandType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_type'],
      )!,
      aggregateType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aggregate_type'],
      )!,
      aggregateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aggregate_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  SyncOutbox createAlias(String alias) {
    return SyncOutbox(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final String operationId;
  final String? organizationId;
  final String? branchId;
  final String? actorUserId;
  final String commandType;
  final String aggregateType;
  final String aggregateId;
  final String payloadJson;
  final String status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SyncOutboxData({
    required this.operationId,
    this.organizationId,
    this.branchId,
    this.actorUserId,
    required this.commandType,
    required this.aggregateType,
    required this.aggregateId,
    required this.payloadJson,
    required this.status,
    required this.attemptCount,
    this.nextAttemptAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    if (!nullToAbsent || organizationId != null) {
      map['organization_id'] = Variable<String>(organizationId);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    if (!nullToAbsent || actorUserId != null) {
      map['actor_user_id'] = Variable<String>(actorUserId);
    }
    map['command_type'] = Variable<String>(commandType);
    map['aggregate_type'] = Variable<String>(aggregateType);
    map['aggregate_id'] = Variable<String>(aggregateId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      operationId: Value(operationId),
      organizationId: organizationId == null && nullToAbsent
          ? const Value.absent()
          : Value(organizationId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      actorUserId: actorUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorUserId),
      commandType: Value(commandType),
      aggregateType: Value(aggregateType),
      aggregateId: Value(aggregateId),
      payloadJson: Value(payloadJson),
      status: Value(status),
      attemptCount: Value(attemptCount),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      operationId: serializer.fromJson<String>(json['operationId']),
      organizationId: serializer.fromJson<String?>(json['organizationId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      actorUserId: serializer.fromJson<String?>(json['actorUserId']),
      commandType: serializer.fromJson<String>(json['commandType']),
      aggregateType: serializer.fromJson<String>(json['aggregateType']),
      aggregateId: serializer.fromJson<String>(json['aggregateId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'organizationId': serializer.toJson<String?>(organizationId),
      'branchId': serializer.toJson<String?>(branchId),
      'actorUserId': serializer.toJson<String?>(actorUserId),
      'commandType': serializer.toJson<String>(commandType),
      'aggregateType': serializer.toJson<String>(aggregateType),
      'aggregateId': serializer.toJson<String>(aggregateId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncOutboxData copyWith({
    String? operationId,
    Value<String?> organizationId = const Value.absent(),
    Value<String?> branchId = const Value.absent(),
    Value<String?> actorUserId = const Value.absent(),
    String? commandType,
    String? aggregateType,
    String? aggregateId,
    String? payloadJson,
    String? status,
    int? attemptCount,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SyncOutboxData(
    operationId: operationId ?? this.operationId,
    organizationId: organizationId.present
        ? organizationId.value
        : this.organizationId,
    branchId: branchId.present ? branchId.value : this.branchId,
    actorUserId: actorUserId.present ? actorUserId.value : this.actorUserId,
    commandType: commandType ?? this.commandType,
    aggregateType: aggregateType ?? this.aggregateType,
    aggregateId: aggregateId ?? this.aggregateId,
    payloadJson: payloadJson ?? this.payloadJson,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      commandType: data.commandType.present
          ? data.commandType.value
          : this.commandType,
      aggregateType: data.aggregateType.present
          ? data.aggregateType.value
          : this.aggregateType,
      aggregateId: data.aggregateId.present
          ? data.aggregateId.value
          : this.aggregateId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('operationId: $operationId, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('commandType: $commandType, ')
          ..write('aggregateType: $aggregateType, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    organizationId,
    branchId,
    actorUserId,
    commandType,
    aggregateType,
    aggregateId,
    payloadJson,
    status,
    attemptCount,
    nextAttemptAt,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.operationId == this.operationId &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.actorUserId == this.actorUserId &&
          other.commandType == this.commandType &&
          other.aggregateType == this.aggregateType &&
          other.aggregateId == this.aggregateId &&
          other.payloadJson == this.payloadJson &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<String> operationId;
  final Value<String?> organizationId;
  final Value<String?> branchId;
  final Value<String?> actorUserId;
  final Value<String> commandType;
  final Value<String> aggregateType;
  final Value<String> aggregateId;
  final Value<String> payloadJson;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.operationId = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.commandType = const Value.absent(),
    this.aggregateType = const Value.absent(),
    this.aggregateId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String operationId,
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.actorUserId = const Value.absent(),
    required String commandType,
    required String aggregateType,
    required String aggregateId,
    required String payloadJson,
    required String status,
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       commandType = Value(commandType),
       aggregateType = Value(aggregateType),
       aggregateId = Value(aggregateId),
       payloadJson = Value(payloadJson),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SyncOutboxData> custom({
    Expression<String>? operationId,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? actorUserId,
    Expression<String>? commandType,
    Expression<String>? aggregateType,
    Expression<String>? aggregateId,
    Expression<String>? payloadJson,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (commandType != null) 'command_type': commandType,
      if (aggregateType != null) 'aggregate_type': aggregateType,
      if (aggregateId != null) 'aggregate_id': aggregateId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<String>? operationId,
    Value<String?>? organizationId,
    Value<String?>? branchId,
    Value<String?>? actorUserId,
    Value<String>? commandType,
    Value<String>? aggregateType,
    Value<String>? aggregateId,
    Value<String>? payloadJson,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncOutboxCompanion(
      operationId: operationId ?? this.operationId,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      actorUserId: actorUserId ?? this.actorUserId,
      commandType: commandType ?? this.commandType,
      aggregateType: aggregateType ?? this.aggregateType,
      aggregateId: aggregateId ?? this.aggregateId,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<String>(actorUserId.value);
    }
    if (commandType.present) {
      map['command_type'] = Variable<String>(commandType.value);
    }
    if (aggregateType.present) {
      map['aggregate_type'] = Variable<String>(aggregateType.value);
    }
    if (aggregateId.present) {
      map['aggregate_id'] = Variable<String>(aggregateId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('operationId: $operationId, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('commandType: $commandType, ')
          ..write('aggregateType: $aggregateType, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncCursors extends Table with TableInfo<SyncCursors, SyncCursorsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncCursors(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> cursorKey = GeneratedColumn<String>(
    'cursor_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> lastChangeSequence = GeneratedColumn<int>(
    'last_change_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cursorKey,
    scope,
    organizationId,
    branchId,
    lastChangeSequence,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  Set<GeneratedColumn> get $primaryKey => {cursorKey};
  @override
  SyncCursorsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursorsData(
      cursorKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor_key'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      ),
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      ),
      lastChangeSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_change_sequence'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  SyncCursors createAlias(String alias) {
    return SyncCursors(attachedDatabase, alias);
  }
}

class SyncCursorsData extends DataClass implements Insertable<SyncCursorsData> {
  final String cursorKey;
  final String scope;
  final String? organizationId;
  final String? branchId;
  final int lastChangeSequence;
  final DateTime? lastSyncedAt;
  const SyncCursorsData({
    required this.cursorKey,
    required this.scope,
    this.organizationId,
    this.branchId,
    required this.lastChangeSequence,
    this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cursor_key'] = Variable<String>(cursorKey);
    map['scope'] = Variable<String>(scope);
    if (!nullToAbsent || organizationId != null) {
      map['organization_id'] = Variable<String>(organizationId);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    map['last_change_sequence'] = Variable<int>(lastChangeSequence);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      cursorKey: Value(cursorKey),
      scope: Value(scope),
      organizationId: organizationId == null && nullToAbsent
          ? const Value.absent()
          : Value(organizationId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      lastChangeSequence: Value(lastChangeSequence),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory SyncCursorsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursorsData(
      cursorKey: serializer.fromJson<String>(json['cursorKey']),
      scope: serializer.fromJson<String>(json['scope']),
      organizationId: serializer.fromJson<String?>(json['organizationId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      lastChangeSequence: serializer.fromJson<int>(json['lastChangeSequence']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cursorKey': serializer.toJson<String>(cursorKey),
      'scope': serializer.toJson<String>(scope),
      'organizationId': serializer.toJson<String?>(organizationId),
      'branchId': serializer.toJson<String?>(branchId),
      'lastChangeSequence': serializer.toJson<int>(lastChangeSequence),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  SyncCursorsData copyWith({
    String? cursorKey,
    String? scope,
    Value<String?> organizationId = const Value.absent(),
    Value<String?> branchId = const Value.absent(),
    int? lastChangeSequence,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => SyncCursorsData(
    cursorKey: cursorKey ?? this.cursorKey,
    scope: scope ?? this.scope,
    organizationId: organizationId.present
        ? organizationId.value
        : this.organizationId,
    branchId: branchId.present ? branchId.value : this.branchId,
    lastChangeSequence: lastChangeSequence ?? this.lastChangeSequence,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  SyncCursorsData copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursorsData(
      cursorKey: data.cursorKey.present ? data.cursorKey.value : this.cursorKey,
      scope: data.scope.present ? data.scope.value : this.scope,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      lastChangeSequence: data.lastChangeSequence.present
          ? data.lastChangeSequence.value
          : this.lastChangeSequence,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsData(')
          ..write('cursorKey: $cursorKey, ')
          ..write('scope: $scope, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('lastChangeSequence: $lastChangeSequence, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cursorKey,
    scope,
    organizationId,
    branchId,
    lastChangeSequence,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursorsData &&
          other.cursorKey == this.cursorKey &&
          other.scope == this.scope &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.lastChangeSequence == this.lastChangeSequence &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursorsData> {
  final Value<String> cursorKey;
  final Value<String> scope;
  final Value<String?> organizationId;
  final Value<String?> branchId;
  final Value<int> lastChangeSequence;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.cursorKey = const Value.absent(),
    this.scope = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.lastChangeSequence = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String cursorKey,
    required String scope,
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.lastChangeSequence = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cursorKey = Value(cursorKey),
       scope = Value(scope);
  static Insertable<SyncCursorsData> custom({
    Expression<String>? cursorKey,
    Expression<String>? scope,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<int>? lastChangeSequence,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cursorKey != null) 'cursor_key': cursorKey,
      if (scope != null) 'scope': scope,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (lastChangeSequence != null)
        'last_change_sequence': lastChangeSequence,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? cursorKey,
    Value<String>? scope,
    Value<String?>? organizationId,
    Value<String?>? branchId,
    Value<int>? lastChangeSequence,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      cursorKey: cursorKey ?? this.cursorKey,
      scope: scope ?? this.scope,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      lastChangeSequence: lastChangeSequence ?? this.lastChangeSequence,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cursorKey.present) {
      map['cursor_key'] = Variable<String>(cursorKey.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (lastChangeSequence.present) {
      map['last_change_sequence'] = Variable<int>(lastChangeSequence.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('cursorKey: $cursorKey, ')
          ..write('scope: $scope, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('lastChangeSequence: $lastChangeSequence, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncConflicts extends Table
    with TableInfo<SyncConflicts, SyncConflictsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncConflicts(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> actorUserId = GeneratedColumn<String>(
    'actor_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> localPayloadJson = GeneratedColumn<String>(
    'local_payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> remotePayloadJson =
      GeneratedColumn<String>(
        'remote_payload_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> resolutionStatus = GeneratedColumn<String>(
    'resolution_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operationId,
    organizationId,
    branchId,
    actorUserId,
    entityType,
    entityId,
    localPayloadJson,
    remotePayloadJson,
    reason,
    resolutionStatus,
    createdAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncConflictsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflictsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      ),
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      ),
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_id'],
      ),
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      localPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_payload_json'],
      )!,
      remotePayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_payload_json'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      resolutionStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  SyncConflicts createAlias(String alias) {
    return SyncConflicts(attachedDatabase, alias);
  }
}

class SyncConflictsData extends DataClass
    implements Insertable<SyncConflictsData> {
  final String id;
  final String operationId;
  final String? organizationId;
  final String? branchId;
  final String? actorUserId;
  final String entityType;
  final String entityId;
  final String localPayloadJson;
  final String remotePayloadJson;
  final String reason;
  final String resolutionStatus;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  const SyncConflictsData({
    required this.id,
    required this.operationId,
    this.organizationId,
    this.branchId,
    this.actorUserId,
    required this.entityType,
    required this.entityId,
    required this.localPayloadJson,
    required this.remotePayloadJson,
    required this.reason,
    required this.resolutionStatus,
    required this.createdAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['operation_id'] = Variable<String>(operationId);
    if (!nullToAbsent || organizationId != null) {
      map['organization_id'] = Variable<String>(organizationId);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    if (!nullToAbsent || actorUserId != null) {
      map['actor_user_id'] = Variable<String>(actorUserId);
    }
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['local_payload_json'] = Variable<String>(localPayloadJson);
    map['remote_payload_json'] = Variable<String>(remotePayloadJson);
    map['reason'] = Variable<String>(reason);
    map['resolution_status'] = Variable<String>(resolutionStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      id: Value(id),
      operationId: Value(operationId),
      organizationId: organizationId == null && nullToAbsent
          ? const Value.absent()
          : Value(organizationId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      actorUserId: actorUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorUserId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      localPayloadJson: Value(localPayloadJson),
      remotePayloadJson: Value(remotePayloadJson),
      reason: Value(reason),
      resolutionStatus: Value(resolutionStatus),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory SyncConflictsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflictsData(
      id: serializer.fromJson<String>(json['id']),
      operationId: serializer.fromJson<String>(json['operationId']),
      organizationId: serializer.fromJson<String?>(json['organizationId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      actorUserId: serializer.fromJson<String?>(json['actorUserId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      localPayloadJson: serializer.fromJson<String>(json['localPayloadJson']),
      remotePayloadJson: serializer.fromJson<String>(json['remotePayloadJson']),
      reason: serializer.fromJson<String>(json['reason']),
      resolutionStatus: serializer.fromJson<String>(json['resolutionStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'operationId': serializer.toJson<String>(operationId),
      'organizationId': serializer.toJson<String?>(organizationId),
      'branchId': serializer.toJson<String?>(branchId),
      'actorUserId': serializer.toJson<String?>(actorUserId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'localPayloadJson': serializer.toJson<String>(localPayloadJson),
      'remotePayloadJson': serializer.toJson<String>(remotePayloadJson),
      'reason': serializer.toJson<String>(reason),
      'resolutionStatus': serializer.toJson<String>(resolutionStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  SyncConflictsData copyWith({
    String? id,
    String? operationId,
    Value<String?> organizationId = const Value.absent(),
    Value<String?> branchId = const Value.absent(),
    Value<String?> actorUserId = const Value.absent(),
    String? entityType,
    String? entityId,
    String? localPayloadJson,
    String? remotePayloadJson,
    String? reason,
    String? resolutionStatus,
    DateTime? createdAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => SyncConflictsData(
    id: id ?? this.id,
    operationId: operationId ?? this.operationId,
    organizationId: organizationId.present
        ? organizationId.value
        : this.organizationId,
    branchId: branchId.present ? branchId.value : this.branchId,
    actorUserId: actorUserId.present ? actorUserId.value : this.actorUserId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    localPayloadJson: localPayloadJson ?? this.localPayloadJson,
    remotePayloadJson: remotePayloadJson ?? this.remotePayloadJson,
    reason: reason ?? this.reason,
    resolutionStatus: resolutionStatus ?? this.resolutionStatus,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  SyncConflictsData copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflictsData(
      id: data.id.present ? data.id.value : this.id,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      localPayloadJson: data.localPayloadJson.present
          ? data.localPayloadJson.value
          : this.localPayloadJson,
      remotePayloadJson: data.remotePayloadJson.present
          ? data.remotePayloadJson.value
          : this.remotePayloadJson,
      reason: data.reason.present ? data.reason.value : this.reason,
      resolutionStatus: data.resolutionStatus.present
          ? data.resolutionStatus.value
          : this.resolutionStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsData(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('localPayloadJson: $localPayloadJson, ')
          ..write('remotePayloadJson: $remotePayloadJson, ')
          ..write('reason: $reason, ')
          ..write('resolutionStatus: $resolutionStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operationId,
    organizationId,
    branchId,
    actorUserId,
    entityType,
    entityId,
    localPayloadJson,
    remotePayloadJson,
    reason,
    resolutionStatus,
    createdAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflictsData &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.actorUserId == this.actorUserId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.localPayloadJson == this.localPayloadJson &&
          other.remotePayloadJson == this.remotePayloadJson &&
          other.reason == this.reason &&
          other.resolutionStatus == this.resolutionStatus &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflictsData> {
  final Value<String> id;
  final Value<String> operationId;
  final Value<String?> organizationId;
  final Value<String?> branchId;
  final Value<String?> actorUserId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> localPayloadJson;
  final Value<String> remotePayloadJson;
  final Value<String> reason;
  final Value<String> resolutionStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  final Value<int> rowid;
  const SyncConflictsCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.localPayloadJson = const Value.absent(),
    this.remotePayloadJson = const Value.absent(),
    this.reason = const Value.absent(),
    this.resolutionStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    required String id,
    required String operationId,
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.actorUserId = const Value.absent(),
    required String entityType,
    required String entityId,
    required String localPayloadJson,
    required String remotePayloadJson,
    required String reason,
    required String resolutionStatus,
    required DateTime createdAt,
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       operationId = Value(operationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       localPayloadJson = Value(localPayloadJson),
       remotePayloadJson = Value(remotePayloadJson),
       reason = Value(reason),
       resolutionStatus = Value(resolutionStatus),
       createdAt = Value(createdAt);
  static Insertable<SyncConflictsData> custom({
    Expression<String>? id,
    Expression<String>? operationId,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? actorUserId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? localPayloadJson,
    Expression<String>? remotePayloadJson,
    Expression<String>? reason,
    Expression<String>? resolutionStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (localPayloadJson != null) 'local_payload_json': localPayloadJson,
      if (remotePayloadJson != null) 'remote_payload_json': remotePayloadJson,
      if (reason != null) 'reason': reason,
      if (resolutionStatus != null) 'resolution_status': resolutionStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<String>? id,
    Value<String>? operationId,
    Value<String?>? organizationId,
    Value<String?>? branchId,
    Value<String?>? actorUserId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? localPayloadJson,
    Value<String>? remotePayloadJson,
    Value<String>? reason,
    Value<String>? resolutionStatus,
    Value<DateTime>? createdAt,
    Value<DateTime?>? resolvedAt,
    Value<int>? rowid,
  }) {
    return SyncConflictsCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      actorUserId: actorUserId ?? this.actorUserId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      localPayloadJson: localPayloadJson ?? this.localPayloadJson,
      remotePayloadJson: remotePayloadJson ?? this.remotePayloadJson,
      reason: reason ?? this.reason,
      resolutionStatus: resolutionStatus ?? this.resolutionStatus,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<String>(actorUserId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (localPayloadJson.present) {
      map['local_payload_json'] = Variable<String>(localPayloadJson.value);
    }
    if (remotePayloadJson.present) {
      map['remote_payload_json'] = Variable<String>(remotePayloadJson.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (resolutionStatus.present) {
      map['resolution_status'] = Variable<String>(resolutionStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('localPayloadJson: $localPayloadJson, ')
          ..write('remotePayloadJson: $remotePayloadJson, ')
          ..write('reason: $reason, ')
          ..write('resolutionStatus: $resolutionStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncEntityVersions extends Table
    with TableInfo<SyncEntityVersions, SyncEntityVersionsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncEntityVersions(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> entityKey = GeneratedColumn<String>(
    'entity_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> remoteVersion = GeneratedColumn<int>(
    'remote_version',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('remote_version >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<String> lastOperationId = GeneratedColumn<String>(
    'last_operation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entityKey,
    organizationId,
    branchId,
    entityType,
    entityId,
    remoteVersion,
    lastOperationId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_entity_versions';
  @override
  Set<GeneratedColumn> get $primaryKey => {entityKey};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, entityType, entityId},
  ];
  @override
  SyncEntityVersionsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncEntityVersionsData(
      entityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_key'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      ),
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      remoteVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_version'],
      )!,
      lastOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_operation_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  SyncEntityVersions createAlias(String alias) {
    return SyncEntityVersions(attachedDatabase, alias);
  }
}

class SyncEntityVersionsData extends DataClass
    implements Insertable<SyncEntityVersionsData> {
  final String entityKey;
  final String organizationId;
  final String? branchId;
  final String entityType;
  final String entityId;
  final int remoteVersion;
  final String? lastOperationId;
  final DateTime updatedAt;
  const SyncEntityVersionsData({
    required this.entityKey,
    required this.organizationId,
    this.branchId,
    required this.entityType,
    required this.entityId,
    required this.remoteVersion,
    this.lastOperationId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_key'] = Variable<String>(entityKey);
    map['organization_id'] = Variable<String>(organizationId);
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['remote_version'] = Variable<int>(remoteVersion);
    if (!nullToAbsent || lastOperationId != null) {
      map['last_operation_id'] = Variable<String>(lastOperationId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncEntityVersionsCompanion toCompanion(bool nullToAbsent) {
    return SyncEntityVersionsCompanion(
      entityKey: Value(entityKey),
      organizationId: Value(organizationId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      remoteVersion: Value(remoteVersion),
      lastOperationId: lastOperationId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOperationId),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncEntityVersionsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncEntityVersionsData(
      entityKey: serializer.fromJson<String>(json['entityKey']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      remoteVersion: serializer.fromJson<int>(json['remoteVersion']),
      lastOperationId: serializer.fromJson<String?>(json['lastOperationId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityKey': serializer.toJson<String>(entityKey),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String?>(branchId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'remoteVersion': serializer.toJson<int>(remoteVersion),
      'lastOperationId': serializer.toJson<String?>(lastOperationId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncEntityVersionsData copyWith({
    String? entityKey,
    String? organizationId,
    Value<String?> branchId = const Value.absent(),
    String? entityType,
    String? entityId,
    int? remoteVersion,
    Value<String?> lastOperationId = const Value.absent(),
    DateTime? updatedAt,
  }) => SyncEntityVersionsData(
    entityKey: entityKey ?? this.entityKey,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId.present ? branchId.value : this.branchId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    remoteVersion: remoteVersion ?? this.remoteVersion,
    lastOperationId: lastOperationId.present
        ? lastOperationId.value
        : this.lastOperationId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncEntityVersionsData copyWithCompanion(SyncEntityVersionsCompanion data) {
    return SyncEntityVersionsData(
      entityKey: data.entityKey.present ? data.entityKey.value : this.entityKey,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      remoteVersion: data.remoteVersion.present
          ? data.remoteVersion.value
          : this.remoteVersion,
      lastOperationId: data.lastOperationId.present
          ? data.lastOperationId.value
          : this.lastOperationId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncEntityVersionsData(')
          ..write('entityKey: $entityKey, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('lastOperationId: $lastOperationId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entityKey,
    organizationId,
    branchId,
    entityType,
    entityId,
    remoteVersion,
    lastOperationId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEntityVersionsData &&
          other.entityKey == this.entityKey &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.remoteVersion == this.remoteVersion &&
          other.lastOperationId == this.lastOperationId &&
          other.updatedAt == this.updatedAt);
}

class SyncEntityVersionsCompanion
    extends UpdateCompanion<SyncEntityVersionsData> {
  final Value<String> entityKey;
  final Value<String> organizationId;
  final Value<String?> branchId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> remoteVersion;
  final Value<String?> lastOperationId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncEntityVersionsCompanion({
    this.entityKey = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.remoteVersion = const Value.absent(),
    this.lastOperationId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncEntityVersionsCompanion.insert({
    required String entityKey,
    required String organizationId,
    this.branchId = const Value.absent(),
    required String entityType,
    required String entityId,
    this.remoteVersion = const Value.absent(),
    this.lastOperationId = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : entityKey = Value(entityKey),
       organizationId = Value(organizationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       updatedAt = Value(updatedAt);
  static Insertable<SyncEntityVersionsData> custom({
    Expression<String>? entityKey,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? remoteVersion,
    Expression<String>? lastOperationId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityKey != null) 'entity_key': entityKey,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (remoteVersion != null) 'remote_version': remoteVersion,
      if (lastOperationId != null) 'last_operation_id': lastOperationId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncEntityVersionsCompanion copyWith({
    Value<String>? entityKey,
    Value<String>? organizationId,
    Value<String?>? branchId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? remoteVersion,
    Value<String?>? lastOperationId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncEntityVersionsCompanion(
      entityKey: entityKey ?? this.entityKey,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      lastOperationId: lastOperationId ?? this.lastOperationId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityKey.present) {
      map['entity_key'] = Variable<String>(entityKey.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (remoteVersion.present) {
      map['remote_version'] = Variable<int>(remoteVersion.value);
    }
    if (lastOperationId.present) {
      map['last_operation_id'] = Variable<String>(lastOperationId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncEntityVersionsCompanion(')
          ..write('entityKey: $entityKey, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('remoteVersion: $remoteVersion, ')
          ..write('lastOperationId: $lastOperationId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class LocalAuditLogs extends Table
    with TableInfo<LocalAuditLogs, LocalAuditLogsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LocalAuditLogs(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> actorUserId = GeneratedColumn<String>(
    'actor_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> auditedEntityName =
      GeneratedColumn<String>(
        'entity_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'{}\''),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operationId,
    organizationId,
    actorUserId,
    branchId,
    deviceId,
    actionType,
    auditedEntityName,
    entityId,
    metadataJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_audit_logs';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAuditLogsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAuditLogsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      ),
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      ),
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      )!,
      auditedEntityName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_name'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  LocalAuditLogs createAlias(String alias) {
    return LocalAuditLogs(attachedDatabase, alias);
  }
}

class LocalAuditLogsData extends DataClass
    implements Insertable<LocalAuditLogsData> {
  final String id;
  final String? operationId;
  final String? organizationId;
  final String actorUserId;
  final String? branchId;
  final String? deviceId;
  final String actionType;
  final String auditedEntityName;
  final String entityId;
  final String metadataJson;
  final DateTime createdAt;
  const LocalAuditLogsData({
    required this.id,
    this.operationId,
    this.organizationId,
    required this.actorUserId,
    this.branchId,
    this.deviceId,
    required this.actionType,
    required this.auditedEntityName,
    required this.entityId,
    required this.metadataJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || operationId != null) {
      map['operation_id'] = Variable<String>(operationId);
    }
    if (!nullToAbsent || organizationId != null) {
      map['organization_id'] = Variable<String>(organizationId);
    }
    map['actor_user_id'] = Variable<String>(actorUserId);
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    map['action_type'] = Variable<String>(actionType);
    map['entity_name'] = Variable<String>(auditedEntityName);
    map['entity_id'] = Variable<String>(entityId);
    map['metadata_json'] = Variable<String>(metadataJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalAuditLogsCompanion toCompanion(bool nullToAbsent) {
    return LocalAuditLogsCompanion(
      id: Value(id),
      operationId: operationId == null && nullToAbsent
          ? const Value.absent()
          : Value(operationId),
      organizationId: organizationId == null && nullToAbsent
          ? const Value.absent()
          : Value(organizationId),
      actorUserId: Value(actorUserId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      actionType: Value(actionType),
      auditedEntityName: Value(auditedEntityName),
      entityId: Value(entityId),
      metadataJson: Value(metadataJson),
      createdAt: Value(createdAt),
    );
  }

  factory LocalAuditLogsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAuditLogsData(
      id: serializer.fromJson<String>(json['id']),
      operationId: serializer.fromJson<String?>(json['operationId']),
      organizationId: serializer.fromJson<String?>(json['organizationId']),
      actorUserId: serializer.fromJson<String>(json['actorUserId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      actionType: serializer.fromJson<String>(json['actionType']),
      auditedEntityName: serializer.fromJson<String>(json['auditedEntityName']),
      entityId: serializer.fromJson<String>(json['entityId']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'operationId': serializer.toJson<String?>(operationId),
      'organizationId': serializer.toJson<String?>(organizationId),
      'actorUserId': serializer.toJson<String>(actorUserId),
      'branchId': serializer.toJson<String?>(branchId),
      'deviceId': serializer.toJson<String?>(deviceId),
      'actionType': serializer.toJson<String>(actionType),
      'auditedEntityName': serializer.toJson<String>(auditedEntityName),
      'entityId': serializer.toJson<String>(entityId),
      'metadataJson': serializer.toJson<String>(metadataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalAuditLogsData copyWith({
    String? id,
    Value<String?> operationId = const Value.absent(),
    Value<String?> organizationId = const Value.absent(),
    String? actorUserId,
    Value<String?> branchId = const Value.absent(),
    Value<String?> deviceId = const Value.absent(),
    String? actionType,
    String? auditedEntityName,
    String? entityId,
    String? metadataJson,
    DateTime? createdAt,
  }) => LocalAuditLogsData(
    id: id ?? this.id,
    operationId: operationId.present ? operationId.value : this.operationId,
    organizationId: organizationId.present
        ? organizationId.value
        : this.organizationId,
    actorUserId: actorUserId ?? this.actorUserId,
    branchId: branchId.present ? branchId.value : this.branchId,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    actionType: actionType ?? this.actionType,
    auditedEntityName: auditedEntityName ?? this.auditedEntityName,
    entityId: entityId ?? this.entityId,
    metadataJson: metadataJson ?? this.metadataJson,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalAuditLogsData copyWithCompanion(LocalAuditLogsCompanion data) {
    return LocalAuditLogsData(
      id: data.id.present ? data.id.value : this.id,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      auditedEntityName: data.auditedEntityName.present
          ? data.auditedEntityName.value
          : this.auditedEntityName,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAuditLogsData(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('organizationId: $organizationId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('branchId: $branchId, ')
          ..write('deviceId: $deviceId, ')
          ..write('actionType: $actionType, ')
          ..write('auditedEntityName: $auditedEntityName, ')
          ..write('entityId: $entityId, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operationId,
    organizationId,
    actorUserId,
    branchId,
    deviceId,
    actionType,
    auditedEntityName,
    entityId,
    metadataJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAuditLogsData &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.organizationId == this.organizationId &&
          other.actorUserId == this.actorUserId &&
          other.branchId == this.branchId &&
          other.deviceId == this.deviceId &&
          other.actionType == this.actionType &&
          other.auditedEntityName == this.auditedEntityName &&
          other.entityId == this.entityId &&
          other.metadataJson == this.metadataJson &&
          other.createdAt == this.createdAt);
}

class LocalAuditLogsCompanion extends UpdateCompanion<LocalAuditLogsData> {
  final Value<String> id;
  final Value<String?> operationId;
  final Value<String?> organizationId;
  final Value<String> actorUserId;
  final Value<String?> branchId;
  final Value<String?> deviceId;
  final Value<String> actionType;
  final Value<String> auditedEntityName;
  final Value<String> entityId;
  final Value<String> metadataJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalAuditLogsCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.actionType = const Value.absent(),
    this.auditedEntityName = const Value.absent(),
    this.entityId = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAuditLogsCompanion.insert({
    required String id,
    this.operationId = const Value.absent(),
    this.organizationId = const Value.absent(),
    required String actorUserId,
    this.branchId = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String actionType,
    required String auditedEntityName,
    required String entityId,
    this.metadataJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       actorUserId = Value(actorUserId),
       actionType = Value(actionType),
       auditedEntityName = Value(auditedEntityName),
       entityId = Value(entityId),
       createdAt = Value(createdAt);
  static Insertable<LocalAuditLogsData> custom({
    Expression<String>? id,
    Expression<String>? operationId,
    Expression<String>? organizationId,
    Expression<String>? actorUserId,
    Expression<String>? branchId,
    Expression<String>? deviceId,
    Expression<String>? actionType,
    Expression<String>? auditedEntityName,
    Expression<String>? entityId,
    Expression<String>? metadataJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (organizationId != null) 'organization_id': organizationId,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (branchId != null) 'branch_id': branchId,
      if (deviceId != null) 'device_id': deviceId,
      if (actionType != null) 'action_type': actionType,
      if (auditedEntityName != null) 'entity_name': auditedEntityName,
      if (entityId != null) 'entity_id': entityId,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAuditLogsCompanion copyWith({
    Value<String>? id,
    Value<String?>? operationId,
    Value<String?>? organizationId,
    Value<String>? actorUserId,
    Value<String?>? branchId,
    Value<String?>? deviceId,
    Value<String>? actionType,
    Value<String>? auditedEntityName,
    Value<String>? entityId,
    Value<String>? metadataJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalAuditLogsCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      organizationId: organizationId ?? this.organizationId,
      actorUserId: actorUserId ?? this.actorUserId,
      branchId: branchId ?? this.branchId,
      deviceId: deviceId ?? this.deviceId,
      actionType: actionType ?? this.actionType,
      auditedEntityName: auditedEntityName ?? this.auditedEntityName,
      entityId: entityId ?? this.entityId,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<String>(actorUserId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (auditedEntityName.present) {
      map['entity_name'] = Variable<String>(auditedEntityName.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('organizationId: $organizationId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('branchId: $branchId, ')
          ..write('deviceId: $deviceId, ')
          ..write('actionType: $actionType, ')
          ..write('auditedEntityName: $auditedEntityName, ')
          ..write('entityId: $entityId, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Organizations extends Table
    with TableInfo<Organizations, OrganizationsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Organizations(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'Asia/Manila\''),
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('1'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    name,
    timezone,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'organizations';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {code},
  ];
  @override
  OrganizationsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrganizationsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  Organizations createAlias(String alias) {
    return Organizations(attachedDatabase, alias);
  }
}

class OrganizationsData extends DataClass
    implements Insertable<OrganizationsData> {
  final String id;
  final String code;
  final String name;
  final String timezone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const OrganizationsData({
    required this.id,
    required this.code,
    required this.name,
    required this.timezone,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['timezone'] = Variable<String>(timezone);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  OrganizationsCompanion toCompanion(bool nullToAbsent) {
    return OrganizationsCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      timezone: Value(timezone),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory OrganizationsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrganizationsData(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      timezone: serializer.fromJson<String>(json['timezone']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'timezone': serializer.toJson<String>(timezone),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  OrganizationsData copyWith({
    String? id,
    String? code,
    String? name,
    String? timezone,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => OrganizationsData(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    timezone: timezone ?? this.timezone,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  OrganizationsData copyWithCompanion(OrganizationsCompanion data) {
    return OrganizationsData(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrganizationsData(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('timezone: $timezone, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    timezone,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrganizationsData &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.timezone == this.timezone &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class OrganizationsCompanion extends UpdateCompanion<OrganizationsData> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<String> timezone;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const OrganizationsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.timezone = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrganizationsCompanion.insert({
    required String id,
    required String code,
    required String name,
    this.timezone = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<OrganizationsData> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? timezone,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (timezone != null) 'timezone': timezone,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrganizationsCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<String>? timezone,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return OrganizationsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      timezone: timezone ?? this.timezone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrganizationsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('timezone: $timezone, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Branches extends Table with TableInfo<Branches, BranchesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Branches(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'Asia/Manila\''),
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('1'),
  );
  late final GeneratedColumn<bool> allowNegativeStock = GeneratedColumn<bool>(
    'allow_negative_stock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_negative_stock" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<int> adjustmentApprovalThresholdMilli =
      GeneratedColumn<int>(
        'adjustment_approval_threshold_milli',
        aliasedName,
        true,
        check: () => const i2.CustomExpression<bool>(
          'adjustment_approval_threshold_milli IS NULL OR '
          'adjustment_approval_threshold_milli >= 0',
        ),
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<bool> allowMultipleOpenShiftsPerUser =
      GeneratedColumn<bool>(
        'allow_multiple_open_shifts_per_user',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("allow_multiple_open_shifts_per_user" IN (0, 1))',
        ),
        defaultValue: const CustomExpression('0'),
      );
  late final GeneratedColumn<bool> allowSalesWithoutOpenShift =
      GeneratedColumn<bool>(
        'allow_sales_without_open_shift',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("allow_sales_without_open_shift" IN (0, 1))',
        ),
        defaultValue: const CustomExpression('0'),
      );
  late final GeneratedColumn<int> cashDiscrepancyApprovalThresholdMinor =
      GeneratedColumn<int>(
        'cash_discrepancy_approval_threshold_minor',
        aliasedName,
        true,
        check: () => const i2.CustomExpression<bool>(
          'cash_discrepancy_approval_threshold_minor IS NULL OR '
          'cash_discrepancy_approval_threshold_minor >= 0',
        ),
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<int> discountApprovalThresholdBasisPoints =
      GeneratedColumn<int>(
        'discount_approval_threshold_basis_points',
        aliasedName,
        true,
        check: () => const i2.CustomExpression<bool>(
          'discount_approval_threshold_basis_points IS NULL OR '
          '(discount_approval_threshold_basis_points >= 0 AND '
          'discount_approval_threshold_basis_points <= 10000)',
        ),
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    code,
    name,
    timezone,
    isActive,
    allowNegativeStock,
    adjustmentApprovalThresholdMilli,
    allowMultipleOpenShiftsPerUser,
    allowSalesWithoutOpenShift,
    cashDiscrepancyApprovalThresholdMinor,
    discountApprovalThresholdBasisPoints,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'branches';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, code},
    {id, organizationId},
  ];
  @override
  BranchesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BranchesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      allowNegativeStock: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_negative_stock'],
      )!,
      adjustmentApprovalThresholdMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}adjustment_approval_threshold_milli'],
      ),
      allowMultipleOpenShiftsPerUser: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_multiple_open_shifts_per_user'],
      )!,
      allowSalesWithoutOpenShift: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_sales_without_open_shift'],
      )!,
      cashDiscrepancyApprovalThresholdMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cash_discrepancy_approval_threshold_minor'],
      ),
      discountApprovalThresholdBasisPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_approval_threshold_basis_points'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  Branches createAlias(String alias) {
    return Branches(attachedDatabase, alias);
  }
}

class BranchesData extends DataClass implements Insertable<BranchesData> {
  final String id;
  final String organizationId;
  final String code;
  final String name;
  final String timezone;
  final bool isActive;
  final bool allowNegativeStock;
  final int? adjustmentApprovalThresholdMilli;
  final bool allowMultipleOpenShiftsPerUser;
  final bool allowSalesWithoutOpenShift;
  final int? cashDiscrepancyApprovalThresholdMinor;
  final int? discountApprovalThresholdBasisPoints;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const BranchesData({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.name,
    required this.timezone,
    required this.isActive,
    required this.allowNegativeStock,
    this.adjustmentApprovalThresholdMilli,
    required this.allowMultipleOpenShiftsPerUser,
    required this.allowSalesWithoutOpenShift,
    this.cashDiscrepancyApprovalThresholdMinor,
    this.discountApprovalThresholdBasisPoints,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['timezone'] = Variable<String>(timezone);
    map['is_active'] = Variable<bool>(isActive);
    map['allow_negative_stock'] = Variable<bool>(allowNegativeStock);
    if (!nullToAbsent || adjustmentApprovalThresholdMilli != null) {
      map['adjustment_approval_threshold_milli'] = Variable<int>(
        adjustmentApprovalThresholdMilli,
      );
    }
    map['allow_multiple_open_shifts_per_user'] = Variable<bool>(
      allowMultipleOpenShiftsPerUser,
    );
    map['allow_sales_without_open_shift'] = Variable<bool>(
      allowSalesWithoutOpenShift,
    );
    if (!nullToAbsent || cashDiscrepancyApprovalThresholdMinor != null) {
      map['cash_discrepancy_approval_threshold_minor'] = Variable<int>(
        cashDiscrepancyApprovalThresholdMinor,
      );
    }
    if (!nullToAbsent || discountApprovalThresholdBasisPoints != null) {
      map['discount_approval_threshold_basis_points'] = Variable<int>(
        discountApprovalThresholdBasisPoints,
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  BranchesCompanion toCompanion(bool nullToAbsent) {
    return BranchesCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      code: Value(code),
      name: Value(name),
      timezone: Value(timezone),
      isActive: Value(isActive),
      allowNegativeStock: Value(allowNegativeStock),
      adjustmentApprovalThresholdMilli:
          adjustmentApprovalThresholdMilli == null && nullToAbsent
          ? const Value.absent()
          : Value(adjustmentApprovalThresholdMilli),
      allowMultipleOpenShiftsPerUser: Value(allowMultipleOpenShiftsPerUser),
      allowSalesWithoutOpenShift: Value(allowSalesWithoutOpenShift),
      cashDiscrepancyApprovalThresholdMinor:
          cashDiscrepancyApprovalThresholdMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(cashDiscrepancyApprovalThresholdMinor),
      discountApprovalThresholdBasisPoints:
          discountApprovalThresholdBasisPoints == null && nullToAbsent
          ? const Value.absent()
          : Value(discountApprovalThresholdBasisPoints),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory BranchesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BranchesData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      timezone: serializer.fromJson<String>(json['timezone']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      allowNegativeStock: serializer.fromJson<bool>(json['allowNegativeStock']),
      adjustmentApprovalThresholdMilli: serializer.fromJson<int?>(
        json['adjustmentApprovalThresholdMilli'],
      ),
      allowMultipleOpenShiftsPerUser: serializer.fromJson<bool>(
        json['allowMultipleOpenShiftsPerUser'],
      ),
      allowSalesWithoutOpenShift: serializer.fromJson<bool>(
        json['allowSalesWithoutOpenShift'],
      ),
      cashDiscrepancyApprovalThresholdMinor: serializer.fromJson<int?>(
        json['cashDiscrepancyApprovalThresholdMinor'],
      ),
      discountApprovalThresholdBasisPoints: serializer.fromJson<int?>(
        json['discountApprovalThresholdBasisPoints'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'timezone': serializer.toJson<String>(timezone),
      'isActive': serializer.toJson<bool>(isActive),
      'allowNegativeStock': serializer.toJson<bool>(allowNegativeStock),
      'adjustmentApprovalThresholdMilli': serializer.toJson<int?>(
        adjustmentApprovalThresholdMilli,
      ),
      'allowMultipleOpenShiftsPerUser': serializer.toJson<bool>(
        allowMultipleOpenShiftsPerUser,
      ),
      'allowSalesWithoutOpenShift': serializer.toJson<bool>(
        allowSalesWithoutOpenShift,
      ),
      'cashDiscrepancyApprovalThresholdMinor': serializer.toJson<int?>(
        cashDiscrepancyApprovalThresholdMinor,
      ),
      'discountApprovalThresholdBasisPoints': serializer.toJson<int?>(
        discountApprovalThresholdBasisPoints,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  BranchesData copyWith({
    String? id,
    String? organizationId,
    String? code,
    String? name,
    String? timezone,
    bool? isActive,
    bool? allowNegativeStock,
    Value<int?> adjustmentApprovalThresholdMilli = const Value.absent(),
    bool? allowMultipleOpenShiftsPerUser,
    bool? allowSalesWithoutOpenShift,
    Value<int?> cashDiscrepancyApprovalThresholdMinor = const Value.absent(),
    Value<int?> discountApprovalThresholdBasisPoints = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => BranchesData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    code: code ?? this.code,
    name: name ?? this.name,
    timezone: timezone ?? this.timezone,
    isActive: isActive ?? this.isActive,
    allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
    adjustmentApprovalThresholdMilli: adjustmentApprovalThresholdMilli.present
        ? adjustmentApprovalThresholdMilli.value
        : this.adjustmentApprovalThresholdMilli,
    allowMultipleOpenShiftsPerUser:
        allowMultipleOpenShiftsPerUser ?? this.allowMultipleOpenShiftsPerUser,
    allowSalesWithoutOpenShift:
        allowSalesWithoutOpenShift ?? this.allowSalesWithoutOpenShift,
    cashDiscrepancyApprovalThresholdMinor:
        cashDiscrepancyApprovalThresholdMinor.present
        ? cashDiscrepancyApprovalThresholdMinor.value
        : this.cashDiscrepancyApprovalThresholdMinor,
    discountApprovalThresholdBasisPoints:
        discountApprovalThresholdBasisPoints.present
        ? discountApprovalThresholdBasisPoints.value
        : this.discountApprovalThresholdBasisPoints,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  BranchesData copyWithCompanion(BranchesCompanion data) {
    return BranchesData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      allowNegativeStock: data.allowNegativeStock.present
          ? data.allowNegativeStock.value
          : this.allowNegativeStock,
      adjustmentApprovalThresholdMilli:
          data.adjustmentApprovalThresholdMilli.present
          ? data.adjustmentApprovalThresholdMilli.value
          : this.adjustmentApprovalThresholdMilli,
      allowMultipleOpenShiftsPerUser:
          data.allowMultipleOpenShiftsPerUser.present
          ? data.allowMultipleOpenShiftsPerUser.value
          : this.allowMultipleOpenShiftsPerUser,
      allowSalesWithoutOpenShift: data.allowSalesWithoutOpenShift.present
          ? data.allowSalesWithoutOpenShift.value
          : this.allowSalesWithoutOpenShift,
      cashDiscrepancyApprovalThresholdMinor:
          data.cashDiscrepancyApprovalThresholdMinor.present
          ? data.cashDiscrepancyApprovalThresholdMinor.value
          : this.cashDiscrepancyApprovalThresholdMinor,
      discountApprovalThresholdBasisPoints:
          data.discountApprovalThresholdBasisPoints.present
          ? data.discountApprovalThresholdBasisPoints.value
          : this.discountApprovalThresholdBasisPoints,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BranchesData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('timezone: $timezone, ')
          ..write('isActive: $isActive, ')
          ..write('allowNegativeStock: $allowNegativeStock, ')
          ..write(
            'adjustmentApprovalThresholdMilli: $adjustmentApprovalThresholdMilli, ',
          )
          ..write(
            'allowMultipleOpenShiftsPerUser: $allowMultipleOpenShiftsPerUser, ',
          )
          ..write('allowSalesWithoutOpenShift: $allowSalesWithoutOpenShift, ')
          ..write(
            'cashDiscrepancyApprovalThresholdMinor: $cashDiscrepancyApprovalThresholdMinor, ',
          )
          ..write(
            'discountApprovalThresholdBasisPoints: $discountApprovalThresholdBasisPoints, ',
          )
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    code,
    name,
    timezone,
    isActive,
    allowNegativeStock,
    adjustmentApprovalThresholdMilli,
    allowMultipleOpenShiftsPerUser,
    allowSalesWithoutOpenShift,
    cashDiscrepancyApprovalThresholdMinor,
    discountApprovalThresholdBasisPoints,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BranchesData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.code == this.code &&
          other.name == this.name &&
          other.timezone == this.timezone &&
          other.isActive == this.isActive &&
          other.allowNegativeStock == this.allowNegativeStock &&
          other.adjustmentApprovalThresholdMilli ==
              this.adjustmentApprovalThresholdMilli &&
          other.allowMultipleOpenShiftsPerUser ==
              this.allowMultipleOpenShiftsPerUser &&
          other.allowSalesWithoutOpenShift == this.allowSalesWithoutOpenShift &&
          other.cashDiscrepancyApprovalThresholdMinor ==
              this.cashDiscrepancyApprovalThresholdMinor &&
          other.discountApprovalThresholdBasisPoints ==
              this.discountApprovalThresholdBasisPoints &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class BranchesCompanion extends UpdateCompanion<BranchesData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> code;
  final Value<String> name;
  final Value<String> timezone;
  final Value<bool> isActive;
  final Value<bool> allowNegativeStock;
  final Value<int?> adjustmentApprovalThresholdMilli;
  final Value<bool> allowMultipleOpenShiftsPerUser;
  final Value<bool> allowSalesWithoutOpenShift;
  final Value<int?> cashDiscrepancyApprovalThresholdMinor;
  final Value<int?> discountApprovalThresholdBasisPoints;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const BranchesCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.timezone = const Value.absent(),
    this.isActive = const Value.absent(),
    this.allowNegativeStock = const Value.absent(),
    this.adjustmentApprovalThresholdMilli = const Value.absent(),
    this.allowMultipleOpenShiftsPerUser = const Value.absent(),
    this.allowSalesWithoutOpenShift = const Value.absent(),
    this.cashDiscrepancyApprovalThresholdMinor = const Value.absent(),
    this.discountApprovalThresholdBasisPoints = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BranchesCompanion.insert({
    required String id,
    required String organizationId,
    required String code,
    required String name,
    this.timezone = const Value.absent(),
    this.isActive = const Value.absent(),
    this.allowNegativeStock = const Value.absent(),
    this.adjustmentApprovalThresholdMilli = const Value.absent(),
    this.allowMultipleOpenShiftsPerUser = const Value.absent(),
    this.allowSalesWithoutOpenShift = const Value.absent(),
    this.cashDiscrepancyApprovalThresholdMinor = const Value.absent(),
    this.discountApprovalThresholdBasisPoints = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       code = Value(code),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BranchesData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? timezone,
    Expression<bool>? isActive,
    Expression<bool>? allowNegativeStock,
    Expression<int>? adjustmentApprovalThresholdMilli,
    Expression<bool>? allowMultipleOpenShiftsPerUser,
    Expression<bool>? allowSalesWithoutOpenShift,
    Expression<int>? cashDiscrepancyApprovalThresholdMinor,
    Expression<int>? discountApprovalThresholdBasisPoints,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (timezone != null) 'timezone': timezone,
      if (isActive != null) 'is_active': isActive,
      if (allowNegativeStock != null)
        'allow_negative_stock': allowNegativeStock,
      if (adjustmentApprovalThresholdMilli != null)
        'adjustment_approval_threshold_milli': adjustmentApprovalThresholdMilli,
      if (allowMultipleOpenShiftsPerUser != null)
        'allow_multiple_open_shifts_per_user': allowMultipleOpenShiftsPerUser,
      if (allowSalesWithoutOpenShift != null)
        'allow_sales_without_open_shift': allowSalesWithoutOpenShift,
      if (cashDiscrepancyApprovalThresholdMinor != null)
        'cash_discrepancy_approval_threshold_minor':
            cashDiscrepancyApprovalThresholdMinor,
      if (discountApprovalThresholdBasisPoints != null)
        'discount_approval_threshold_basis_points':
            discountApprovalThresholdBasisPoints,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BranchesCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? code,
    Value<String>? name,
    Value<String>? timezone,
    Value<bool>? isActive,
    Value<bool>? allowNegativeStock,
    Value<int?>? adjustmentApprovalThresholdMilli,
    Value<bool>? allowMultipleOpenShiftsPerUser,
    Value<bool>? allowSalesWithoutOpenShift,
    Value<int?>? cashDiscrepancyApprovalThresholdMinor,
    Value<int?>? discountApprovalThresholdBasisPoints,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return BranchesCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      code: code ?? this.code,
      name: name ?? this.name,
      timezone: timezone ?? this.timezone,
      isActive: isActive ?? this.isActive,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      adjustmentApprovalThresholdMilli:
          adjustmentApprovalThresholdMilli ??
          this.adjustmentApprovalThresholdMilli,
      allowMultipleOpenShiftsPerUser:
          allowMultipleOpenShiftsPerUser ?? this.allowMultipleOpenShiftsPerUser,
      allowSalesWithoutOpenShift:
          allowSalesWithoutOpenShift ?? this.allowSalesWithoutOpenShift,
      cashDiscrepancyApprovalThresholdMinor:
          cashDiscrepancyApprovalThresholdMinor ??
          this.cashDiscrepancyApprovalThresholdMinor,
      discountApprovalThresholdBasisPoints:
          discountApprovalThresholdBasisPoints ??
          this.discountApprovalThresholdBasisPoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (allowNegativeStock.present) {
      map['allow_negative_stock'] = Variable<bool>(allowNegativeStock.value);
    }
    if (adjustmentApprovalThresholdMilli.present) {
      map['adjustment_approval_threshold_milli'] = Variable<int>(
        adjustmentApprovalThresholdMilli.value,
      );
    }
    if (allowMultipleOpenShiftsPerUser.present) {
      map['allow_multiple_open_shifts_per_user'] = Variable<bool>(
        allowMultipleOpenShiftsPerUser.value,
      );
    }
    if (allowSalesWithoutOpenShift.present) {
      map['allow_sales_without_open_shift'] = Variable<bool>(
        allowSalesWithoutOpenShift.value,
      );
    }
    if (cashDiscrepancyApprovalThresholdMinor.present) {
      map['cash_discrepancy_approval_threshold_minor'] = Variable<int>(
        cashDiscrepancyApprovalThresholdMinor.value,
      );
    }
    if (discountApprovalThresholdBasisPoints.present) {
      map['discount_approval_threshold_basis_points'] = Variable<int>(
        discountApprovalThresholdBasisPoints.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BranchesCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('timezone: $timezone, ')
          ..write('isActive: $isActive, ')
          ..write('allowNegativeStock: $allowNegativeStock, ')
          ..write(
            'adjustmentApprovalThresholdMilli: $adjustmentApprovalThresholdMilli, ',
          )
          ..write(
            'allowMultipleOpenShiftsPerUser: $allowMultipleOpenShiftsPerUser, ',
          )
          ..write('allowSalesWithoutOpenShift: $allowSalesWithoutOpenShift, ')
          ..write(
            'cashDiscrepancyApprovalThresholdMinor: $cashDiscrepancyApprovalThresholdMinor, ',
          )
          ..write(
            'discountApprovalThresholdBasisPoints: $discountApprovalThresholdBasisPoints, ',
          )
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AppUsers extends Table with TableInfo<AppUsers, AppUsersData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AppUsers(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> firebaseUid = GeneratedColumn<String>(
    'firebase_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    firebaseUid,
    email,
    displayName,
    status,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_users';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, email},
  ];
  @override
  AppUsersData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppUsersData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      firebaseUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firebase_uid'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  AppUsers createAlias(String alias) {
    return AppUsers(attachedDatabase, alias);
  }
}

class AppUsersData extends DataClass implements Insertable<AppUsersData> {
  final String id;
  final String organizationId;
  final String? firebaseUid;
  final String email;
  final String displayName;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const AppUsersData({
    required this.id,
    required this.organizationId,
    this.firebaseUid,
    required this.email,
    required this.displayName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    if (!nullToAbsent || firebaseUid != null) {
      map['firebase_uid'] = Variable<String>(firebaseUid);
    }
    map['email'] = Variable<String>(email);
    map['display_name'] = Variable<String>(displayName);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  AppUsersCompanion toCompanion(bool nullToAbsent) {
    return AppUsersCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      firebaseUid: firebaseUid == null && nullToAbsent
          ? const Value.absent()
          : Value(firebaseUid),
      email: Value(email),
      displayName: Value(displayName),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory AppUsersData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppUsersData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      firebaseUid: serializer.fromJson<String?>(json['firebaseUid']),
      email: serializer.fromJson<String>(json['email']),
      displayName: serializer.fromJson<String>(json['displayName']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'firebaseUid': serializer.toJson<String?>(firebaseUid),
      'email': serializer.toJson<String>(email),
      'displayName': serializer.toJson<String>(displayName),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  AppUsersData copyWith({
    String? id,
    String? organizationId,
    Value<String?> firebaseUid = const Value.absent(),
    String? email,
    String? displayName,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => AppUsersData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    firebaseUid: firebaseUid.present ? firebaseUid.value : this.firebaseUid,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  AppUsersData copyWithCompanion(AppUsersCompanion data) {
    return AppUsersData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      firebaseUid: data.firebaseUid.present
          ? data.firebaseUid.value
          : this.firebaseUid,
      email: data.email.present ? data.email.value : this.email,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppUsersData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    firebaseUid,
    email,
    displayName,
    status,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUsersData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.firebaseUid == this.firebaseUid &&
          other.email == this.email &&
          other.displayName == this.displayName &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class AppUsersCompanion extends UpdateCompanion<AppUsersData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String?> firebaseUid;
  final Value<String> email;
  final Value<String> displayName;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const AppUsersCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.firebaseUid = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppUsersCompanion.insert({
    required String id,
    required String organizationId,
    this.firebaseUid = const Value.absent(),
    required String email,
    required String displayName,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       email = Value(email),
       displayName = Value(displayName),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AppUsersData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? firebaseUid,
    Expression<String>? email,
    Expression<String>? displayName,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppUsersCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String?>? firebaseUid,
    Value<String>? email,
    Value<String>? displayName,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AppUsersCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (firebaseUid.present) {
      map['firebase_uid'] = Variable<String>(firebaseUid.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppUsersCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Roles extends Table with TableInfo<Roles, RolesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Roles(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('1'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    code,
    name,
    description,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'roles';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, code},
  ];
  @override
  RolesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RolesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  Roles createAlias(String alias) {
    return Roles(attachedDatabase, alias);
  }
}

class RolesData extends DataClass implements Insertable<RolesData> {
  final String id;
  final String organizationId;
  final String code;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const RolesData({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.name,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  RolesCompanion toCompanion(bool nullToAbsent) {
    return RolesCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      code: Value(code),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory RolesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RolesData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  RolesData copyWith({
    String? id,
    String? organizationId,
    String? code,
    String? name,
    Value<String?> description = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => RolesData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    code: code ?? this.code,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  RolesData copyWithCompanion(RolesCompanion data) {
    return RolesData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RolesData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    code,
    name,
    description,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RolesData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.code == this.code &&
          other.name == this.name &&
          other.description == this.description &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class RolesCompanion extends UpdateCompanion<RolesData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> code;
  final Value<String> name;
  final Value<String?> description;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const RolesCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RolesCompanion.insert({
    required String id,
    required String organizationId,
    required String code,
    required String name,
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       code = Value(code),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RolesData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RolesCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? code,
    Value<String>? name,
    Value<String?>? description,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return RolesCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RolesCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Permissions extends Table with TableInfo<Permissions, PermissionsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Permissions(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [code, name, description, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'permissions';
  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  PermissionsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PermissionsData(
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  Permissions createAlias(String alias) {
    return Permissions(attachedDatabase, alias);
  }
}

class PermissionsData extends DataClass implements Insertable<PermissionsData> {
  final String code;
  final String name;
  final String? description;
  final DateTime createdAt;
  const PermissionsData({
    required this.code,
    required this.name,
    this.description,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PermissionsCompanion toCompanion(bool nullToAbsent) {
    return PermissionsCompanion(
      code: Value(code),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
    );
  }

  factory PermissionsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PermissionsData(
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PermissionsData copyWith({
    String? code,
    String? name,
    Value<String?> description = const Value.absent(),
    DateTime? createdAt,
  }) => PermissionsData(
    code: code ?? this.code,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
  );
  PermissionsData copyWithCompanion(PermissionsCompanion data) {
    return PermissionsData(
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PermissionsData(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(code, name, description, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionsData &&
          other.code == this.code &&
          other.name == this.name &&
          other.description == this.description &&
          other.createdAt == this.createdAt);
}

class PermissionsCompanion extends UpdateCompanion<PermissionsData> {
  final Value<String> code;
  final Value<String> name;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PermissionsCompanion({
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PermissionsCompanion.insert({
    required String code,
    required String name,
    this.description = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : code = Value(code),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<PermissionsData> custom({
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PermissionsCompanion copyWith({
    Value<String>? code,
    Value<String>? name,
    Value<String?>? description,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PermissionsCompanion(
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PermissionsCompanion(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class RolePermissions extends Table
    with TableInfo<RolePermissions, RolePermissionsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  RolePermissions(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> roleId = GeneratedColumn<String>(
    'role_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES roles (id) ON DELETE CASCADE',
    ),
  );
  late final GeneratedColumn<String> permissionCode = GeneratedColumn<String>(
    'permission_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES permissions (code) ON DELETE CASCADE',
    ),
  );
  late final GeneratedColumn<DateTime> grantedAt = GeneratedColumn<DateTime>(
    'granted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [roleId, permissionCode, grantedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'role_permissions';
  @override
  Set<GeneratedColumn> get $primaryKey => {roleId, permissionCode};
  @override
  RolePermissionsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RolePermissionsData(
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_id'],
      )!,
      permissionCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission_code'],
      )!,
      grantedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}granted_at'],
      )!,
    );
  }

  @override
  RolePermissions createAlias(String alias) {
    return RolePermissions(attachedDatabase, alias);
  }
}

class RolePermissionsData extends DataClass
    implements Insertable<RolePermissionsData> {
  final String roleId;
  final String permissionCode;
  final DateTime grantedAt;
  const RolePermissionsData({
    required this.roleId,
    required this.permissionCode,
    required this.grantedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['role_id'] = Variable<String>(roleId);
    map['permission_code'] = Variable<String>(permissionCode);
    map['granted_at'] = Variable<DateTime>(grantedAt);
    return map;
  }

  RolePermissionsCompanion toCompanion(bool nullToAbsent) {
    return RolePermissionsCompanion(
      roleId: Value(roleId),
      permissionCode: Value(permissionCode),
      grantedAt: Value(grantedAt),
    );
  }

  factory RolePermissionsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RolePermissionsData(
      roleId: serializer.fromJson<String>(json['roleId']),
      permissionCode: serializer.fromJson<String>(json['permissionCode']),
      grantedAt: serializer.fromJson<DateTime>(json['grantedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'roleId': serializer.toJson<String>(roleId),
      'permissionCode': serializer.toJson<String>(permissionCode),
      'grantedAt': serializer.toJson<DateTime>(grantedAt),
    };
  }

  RolePermissionsData copyWith({
    String? roleId,
    String? permissionCode,
    DateTime? grantedAt,
  }) => RolePermissionsData(
    roleId: roleId ?? this.roleId,
    permissionCode: permissionCode ?? this.permissionCode,
    grantedAt: grantedAt ?? this.grantedAt,
  );
  RolePermissionsData copyWithCompanion(RolePermissionsCompanion data) {
    return RolePermissionsData(
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      permissionCode: data.permissionCode.present
          ? data.permissionCode.value
          : this.permissionCode,
      grantedAt: data.grantedAt.present ? data.grantedAt.value : this.grantedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RolePermissionsData(')
          ..write('roleId: $roleId, ')
          ..write('permissionCode: $permissionCode, ')
          ..write('grantedAt: $grantedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(roleId, permissionCode, grantedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RolePermissionsData &&
          other.roleId == this.roleId &&
          other.permissionCode == this.permissionCode &&
          other.grantedAt == this.grantedAt);
}

class RolePermissionsCompanion extends UpdateCompanion<RolePermissionsData> {
  final Value<String> roleId;
  final Value<String> permissionCode;
  final Value<DateTime> grantedAt;
  final Value<int> rowid;
  const RolePermissionsCompanion({
    this.roleId = const Value.absent(),
    this.permissionCode = const Value.absent(),
    this.grantedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RolePermissionsCompanion.insert({
    required String roleId,
    required String permissionCode,
    required DateTime grantedAt,
    this.rowid = const Value.absent(),
  }) : roleId = Value(roleId),
       permissionCode = Value(permissionCode),
       grantedAt = Value(grantedAt);
  static Insertable<RolePermissionsData> custom({
    Expression<String>? roleId,
    Expression<String>? permissionCode,
    Expression<DateTime>? grantedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (roleId != null) 'role_id': roleId,
      if (permissionCode != null) 'permission_code': permissionCode,
      if (grantedAt != null) 'granted_at': grantedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RolePermissionsCompanion copyWith({
    Value<String>? roleId,
    Value<String>? permissionCode,
    Value<DateTime>? grantedAt,
    Value<int>? rowid,
  }) {
    return RolePermissionsCompanion(
      roleId: roleId ?? this.roleId,
      permissionCode: permissionCode ?? this.permissionCode,
      grantedAt: grantedAt ?? this.grantedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (roleId.present) {
      map['role_id'] = Variable<String>(roleId.value);
    }
    if (permissionCode.present) {
      map['permission_code'] = Variable<String>(permissionCode.value);
    }
    if (grantedAt.present) {
      map['granted_at'] = Variable<DateTime>(grantedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RolePermissionsCompanion(')
          ..write('roleId: $roleId, ')
          ..write('permissionCode: $permissionCode, ')
          ..write('grantedAt: $grantedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class UserRoleAssignments extends Table
    with TableInfo<UserRoleAssignments, UserRoleAssignmentsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UserRoleAssignments(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES app_users (id) ON DELETE CASCADE',
    ),
  );
  late final GeneratedColumn<String> roleId = GeneratedColumn<String>(
    'role_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES roles (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<DateTime> assignedAt = GeneratedColumn<DateTime>(
    'assigned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> revokedAt = GeneratedColumn<DateTime>(
    'revoked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    userId,
    roleId,
    assignedAt,
    revokedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_role_assignments';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserRoleAssignmentsData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserRoleAssignmentsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_id'],
      )!,
      assignedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}assigned_at'],
      )!,
      revokedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}revoked_at'],
      ),
    );
  }

  @override
  UserRoleAssignments createAlias(String alias) {
    return UserRoleAssignments(attachedDatabase, alias);
  }
}

class UserRoleAssignmentsData extends DataClass
    implements Insertable<UserRoleAssignmentsData> {
  final String id;
  final String organizationId;
  final String? branchId;
  final String userId;
  final String roleId;
  final DateTime assignedAt;
  final DateTime? revokedAt;
  const UserRoleAssignmentsData({
    required this.id,
    required this.organizationId,
    this.branchId,
    required this.userId,
    required this.roleId,
    required this.assignedAt,
    this.revokedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    map['user_id'] = Variable<String>(userId);
    map['role_id'] = Variable<String>(roleId);
    map['assigned_at'] = Variable<DateTime>(assignedAt);
    if (!nullToAbsent || revokedAt != null) {
      map['revoked_at'] = Variable<DateTime>(revokedAt);
    }
    return map;
  }

  UserRoleAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return UserRoleAssignmentsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      userId: Value(userId),
      roleId: Value(roleId),
      assignedAt: Value(assignedAt),
      revokedAt: revokedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(revokedAt),
    );
  }

  factory UserRoleAssignmentsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserRoleAssignmentsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      userId: serializer.fromJson<String>(json['userId']),
      roleId: serializer.fromJson<String>(json['roleId']),
      assignedAt: serializer.fromJson<DateTime>(json['assignedAt']),
      revokedAt: serializer.fromJson<DateTime?>(json['revokedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String?>(branchId),
      'userId': serializer.toJson<String>(userId),
      'roleId': serializer.toJson<String>(roleId),
      'assignedAt': serializer.toJson<DateTime>(assignedAt),
      'revokedAt': serializer.toJson<DateTime?>(revokedAt),
    };
  }

  UserRoleAssignmentsData copyWith({
    String? id,
    String? organizationId,
    Value<String?> branchId = const Value.absent(),
    String? userId,
    String? roleId,
    DateTime? assignedAt,
    Value<DateTime?> revokedAt = const Value.absent(),
  }) => UserRoleAssignmentsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId.present ? branchId.value : this.branchId,
    userId: userId ?? this.userId,
    roleId: roleId ?? this.roleId,
    assignedAt: assignedAt ?? this.assignedAt,
    revokedAt: revokedAt.present ? revokedAt.value : this.revokedAt,
  );
  UserRoleAssignmentsData copyWithCompanion(UserRoleAssignmentsCompanion data) {
    return UserRoleAssignmentsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      userId: data.userId.present ? data.userId.value : this.userId,
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      assignedAt: data.assignedAt.present
          ? data.assignedAt.value
          : this.assignedAt,
      revokedAt: data.revokedAt.present ? data.revokedAt.value : this.revokedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserRoleAssignmentsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('userId: $userId, ')
          ..write('roleId: $roleId, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('revokedAt: $revokedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    userId,
    roleId,
    assignedAt,
    revokedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserRoleAssignmentsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.userId == this.userId &&
          other.roleId == this.roleId &&
          other.assignedAt == this.assignedAt &&
          other.revokedAt == this.revokedAt);
}

class UserRoleAssignmentsCompanion
    extends UpdateCompanion<UserRoleAssignmentsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String?> branchId;
  final Value<String> userId;
  final Value<String> roleId;
  final Value<DateTime> assignedAt;
  final Value<DateTime?> revokedAt;
  final Value<int> rowid;
  const UserRoleAssignmentsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.userId = const Value.absent(),
    this.roleId = const Value.absent(),
    this.assignedAt = const Value.absent(),
    this.revokedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserRoleAssignmentsCompanion.insert({
    required String id,
    required String organizationId,
    this.branchId = const Value.absent(),
    required String userId,
    required String roleId,
    required DateTime assignedAt,
    this.revokedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       userId = Value(userId),
       roleId = Value(roleId),
       assignedAt = Value(assignedAt);
  static Insertable<UserRoleAssignmentsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? userId,
    Expression<String>? roleId,
    Expression<DateTime>? assignedAt,
    Expression<DateTime>? revokedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (userId != null) 'user_id': userId,
      if (roleId != null) 'role_id': roleId,
      if (assignedAt != null) 'assigned_at': assignedAt,
      if (revokedAt != null) 'revoked_at': revokedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserRoleAssignmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String?>? branchId,
    Value<String>? userId,
    Value<String>? roleId,
    Value<DateTime>? assignedAt,
    Value<DateTime?>? revokedAt,
    Value<int>? rowid,
  }) {
    return UserRoleAssignmentsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      userId: userId ?? this.userId,
      roleId: roleId ?? this.roleId,
      assignedAt: assignedAt ?? this.assignedAt,
      revokedAt: revokedAt ?? this.revokedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (roleId.present) {
      map['role_id'] = Variable<String>(roleId.value);
    }
    if (assignedAt.present) {
      map['assigned_at'] = Variable<DateTime>(assignedAt.value);
    }
    if (revokedAt.present) {
      map['revoked_at'] = Variable<DateTime>(revokedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserRoleAssignmentsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('userId: $userId, ')
          ..write('roleId: $roleId, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('revokedAt: $revokedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Categories extends Table with TableInfo<Categories, CategoriesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Categories(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('1'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    name,
    normalizedName,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, normalizedName},
    {id, organizationId},
  ];
  @override
  CategoriesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoriesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  Categories createAlias(String alias) {
    return Categories(attachedDatabase, alias);
  }
}

class CategoriesData extends DataClass implements Insertable<CategoriesData> {
  final String id;
  final String organizationId;
  final String name;
  final String normalizedName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const CategoriesData({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.normalizedName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      name: Value(name),
      normalizedName: Value(normalizedName),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CategoriesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoriesData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  CategoriesData copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? normalizedName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => CategoriesData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CategoriesData copyWithCompanion(CategoriesCompanion data) {
    return CategoriesData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    name,
    normalizedName,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoriesData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CategoriesCompanion extends UpdateCompanion<CategoriesData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String organizationId,
    required String name,
    required String normalizedName,
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       name = Value(name),
       normalizedName = Value(normalizedName),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CategoriesData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Units extends Table with TableInfo<Units, UnitsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Units(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> abbreviation = GeneratedColumn<String>(
    'abbreviation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> allowsFractional = GeneratedColumn<bool>(
    'allows_fractional',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allows_fractional" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('1'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    code,
    name,
    abbreviation,
    allowsFractional,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'units';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, code},
    {id, organizationId},
  ];
  @override
  UnitsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnitsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      abbreviation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}abbreviation'],
      )!,
      allowsFractional: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allows_fractional'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  Units createAlias(String alias) {
    return Units(attachedDatabase, alias);
  }
}

class UnitsData extends DataClass implements Insertable<UnitsData> {
  final String id;
  final String organizationId;
  final String code;
  final String name;
  final String abbreviation;
  final bool allowsFractional;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const UnitsData({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.name,
    required this.abbreviation,
    required this.allowsFractional,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['abbreviation'] = Variable<String>(abbreviation);
    map['allows_fractional'] = Variable<bool>(allowsFractional);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  UnitsCompanion toCompanion(bool nullToAbsent) {
    return UnitsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      code: Value(code),
      name: Value(name),
      abbreviation: Value(abbreviation),
      allowsFractional: Value(allowsFractional),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory UnitsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnitsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      abbreviation: serializer.fromJson<String>(json['abbreviation']),
      allowsFractional: serializer.fromJson<bool>(json['allowsFractional']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'abbreviation': serializer.toJson<String>(abbreviation),
      'allowsFractional': serializer.toJson<bool>(allowsFractional),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  UnitsData copyWith({
    String? id,
    String? organizationId,
    String? code,
    String? name,
    String? abbreviation,
    bool? allowsFractional,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => UnitsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    code: code ?? this.code,
    name: name ?? this.name,
    abbreviation: abbreviation ?? this.abbreviation,
    allowsFractional: allowsFractional ?? this.allowsFractional,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  UnitsData copyWithCompanion(UnitsCompanion data) {
    return UnitsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      abbreviation: data.abbreviation.present
          ? data.abbreviation.value
          : this.abbreviation,
      allowsFractional: data.allowsFractional.present
          ? data.allowsFractional.value
          : this.allowsFractional,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnitsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('abbreviation: $abbreviation, ')
          ..write('allowsFractional: $allowsFractional, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    code,
    name,
    abbreviation,
    allowsFractional,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnitsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.code == this.code &&
          other.name == this.name &&
          other.abbreviation == this.abbreviation &&
          other.allowsFractional == this.allowsFractional &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class UnitsCompanion extends UpdateCompanion<UnitsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> code;
  final Value<String> name;
  final Value<String> abbreviation;
  final Value<bool> allowsFractional;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const UnitsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.abbreviation = const Value.absent(),
    this.allowsFractional = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UnitsCompanion.insert({
    required String id,
    required String organizationId,
    required String code,
    required String name,
    required String abbreviation,
    this.allowsFractional = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       code = Value(code),
       name = Value(name),
       abbreviation = Value(abbreviation),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UnitsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? abbreviation,
    Expression<bool>? allowsFractional,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (abbreviation != null) 'abbreviation': abbreviation,
      if (allowsFractional != null) 'allows_fractional': allowsFractional,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UnitsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? code,
    Value<String>? name,
    Value<String>? abbreviation,
    Value<bool>? allowsFractional,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return UnitsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      code: code ?? this.code,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      allowsFractional: allowsFractional ?? this.allowsFractional,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (abbreviation.present) {
      map['abbreviation'] = Variable<String>(abbreviation.value);
    }
    if (allowsFractional.present) {
      map['allows_fractional'] = Variable<bool>(allowsFractional.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnitsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('abbreviation: $abbreviation, ')
          ..write('allowsFractional: $allowsFractional, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class TaxCategories extends Table
    with TableInfo<TaxCategories, TaxCategoriesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TaxCategories(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> rateBasisPoints = GeneratedColumn<int>(
    'rate_basis_points',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>(
      'rate_basis_points >= 0 AND rate_basis_points <= 10000',
    ),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<bool> isInclusive = GeneratedColumn<bool>(
    'is_inclusive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_inclusive" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('1'),
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('1'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    code,
    name,
    rateBasisPoints,
    isInclusive,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tax_categories';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, code},
    {id, organizationId},
  ];
  @override
  TaxCategoriesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaxCategoriesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      rateBasisPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_basis_points'],
      )!,
      isInclusive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_inclusive'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  TaxCategories createAlias(String alias) {
    return TaxCategories(attachedDatabase, alias);
  }
}

class TaxCategoriesData extends DataClass
    implements Insertable<TaxCategoriesData> {
  final String id;
  final String organizationId;
  final String code;
  final String name;
  final int rateBasisPoints;
  final bool isInclusive;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const TaxCategoriesData({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.name,
    required this.rateBasisPoints,
    required this.isInclusive,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['rate_basis_points'] = Variable<int>(rateBasisPoints);
    map['is_inclusive'] = Variable<bool>(isInclusive);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TaxCategoriesCompanion toCompanion(bool nullToAbsent) {
    return TaxCategoriesCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      code: Value(code),
      name: Value(name),
      rateBasisPoints: Value(rateBasisPoints),
      isInclusive: Value(isInclusive),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TaxCategoriesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaxCategoriesData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      rateBasisPoints: serializer.fromJson<int>(json['rateBasisPoints']),
      isInclusive: serializer.fromJson<bool>(json['isInclusive']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'rateBasisPoints': serializer.toJson<int>(rateBasisPoints),
      'isInclusive': serializer.toJson<bool>(isInclusive),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  TaxCategoriesData copyWith({
    String? id,
    String? organizationId,
    String? code,
    String? name,
    int? rateBasisPoints,
    bool? isInclusive,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => TaxCategoriesData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    code: code ?? this.code,
    name: name ?? this.name,
    rateBasisPoints: rateBasisPoints ?? this.rateBasisPoints,
    isInclusive: isInclusive ?? this.isInclusive,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  TaxCategoriesData copyWithCompanion(TaxCategoriesCompanion data) {
    return TaxCategoriesData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      rateBasisPoints: data.rateBasisPoints.present
          ? data.rateBasisPoints.value
          : this.rateBasisPoints,
      isInclusive: data.isInclusive.present
          ? data.isInclusive.value
          : this.isInclusive,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaxCategoriesData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('rateBasisPoints: $rateBasisPoints, ')
          ..write('isInclusive: $isInclusive, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    code,
    name,
    rateBasisPoints,
    isInclusive,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaxCategoriesData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.code == this.code &&
          other.name == this.name &&
          other.rateBasisPoints == this.rateBasisPoints &&
          other.isInclusive == this.isInclusive &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TaxCategoriesCompanion extends UpdateCompanion<TaxCategoriesData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> code;
  final Value<String> name;
  final Value<int> rateBasisPoints;
  final Value<bool> isInclusive;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TaxCategoriesCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.rateBasisPoints = const Value.absent(),
    this.isInclusive = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaxCategoriesCompanion.insert({
    required String id,
    required String organizationId,
    required String code,
    required String name,
    required int rateBasisPoints,
    this.isInclusive = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       code = Value(code),
       name = Value(name),
       rateBasisPoints = Value(rateBasisPoints),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaxCategoriesData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<int>? rateBasisPoints,
    Expression<bool>? isInclusive,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (rateBasisPoints != null) 'rate_basis_points': rateBasisPoints,
      if (isInclusive != null) 'is_inclusive': isInclusive,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaxCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? code,
    Value<String>? name,
    Value<int>? rateBasisPoints,
    Value<bool>? isInclusive,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TaxCategoriesCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      code: code ?? this.code,
      name: name ?? this.name,
      rateBasisPoints: rateBasisPoints ?? this.rateBasisPoints,
      isInclusive: isInclusive ?? this.isInclusive,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rateBasisPoints.present) {
      map['rate_basis_points'] = Variable<int>(rateBasisPoints.value);
    }
    if (isInclusive.present) {
      map['is_inclusive'] = Variable<bool>(isInclusive.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaxCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('rateBasisPoints: $rateBasisPoints, ')
          ..write('isInclusive: $isInclusive, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Products extends Table with TableInfo<Products, ProductsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Products(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> unitId = GeneratedColumn<String>(
    'unit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES units (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> taxCategoryId = GeneratedColumn<String>(
    'tax_category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tax_categories (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
    'sku',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> normalizedSku = GeneratedColumn<String>(
    'normalized_sku',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('1'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    categoryId,
    unitId,
    taxCategoryId,
    sku,
    normalizedSku,
    name,
    normalizedName,
    description,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, sku},
    {organizationId, normalizedSku},
    {id, organizationId},
  ];
  @override
  ProductsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      unitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_id'],
      )!,
      taxCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tax_category_id'],
      ),
      sku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku'],
      )!,
      normalizedSku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_sku'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  Products createAlias(String alias) {
    return Products(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (category_id, organization_id) REFERENCES categories (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (unit_id, organization_id) REFERENCES units (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (tax_category_id, organization_id) REFERENCES tax_categories (id, organization_id) ON DELETE RESTRICT',
  ];
}

class ProductsData extends DataClass implements Insertable<ProductsData> {
  final String id;
  final String organizationId;
  final String? categoryId;
  final String unitId;
  final String? taxCategoryId;
  final String sku;
  final String normalizedSku;
  final String name;
  final String normalizedName;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ProductsData({
    required this.id,
    required this.organizationId,
    this.categoryId,
    required this.unitId,
    this.taxCategoryId,
    required this.sku,
    required this.normalizedSku,
    required this.name,
    required this.normalizedName,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['unit_id'] = Variable<String>(unitId);
    if (!nullToAbsent || taxCategoryId != null) {
      map['tax_category_id'] = Variable<String>(taxCategoryId);
    }
    map['sku'] = Variable<String>(sku);
    map['normalized_sku'] = Variable<String>(normalizedSku);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      unitId: Value(unitId),
      taxCategoryId: taxCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(taxCategoryId),
      sku: Value(sku),
      normalizedSku: Value(normalizedSku),
      name: Value(name),
      normalizedName: Value(normalizedName),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ProductsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      unitId: serializer.fromJson<String>(json['unitId']),
      taxCategoryId: serializer.fromJson<String?>(json['taxCategoryId']),
      sku: serializer.fromJson<String>(json['sku']),
      normalizedSku: serializer.fromJson<String>(json['normalizedSku']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      description: serializer.fromJson<String?>(json['description']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'unitId': serializer.toJson<String>(unitId),
      'taxCategoryId': serializer.toJson<String?>(taxCategoryId),
      'sku': serializer.toJson<String>(sku),
      'normalizedSku': serializer.toJson<String>(normalizedSku),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'description': serializer.toJson<String?>(description),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ProductsData copyWith({
    String? id,
    String? organizationId,
    Value<String?> categoryId = const Value.absent(),
    String? unitId,
    Value<String?> taxCategoryId = const Value.absent(),
    String? sku,
    String? normalizedSku,
    String? name,
    String? normalizedName,
    Value<String?> description = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ProductsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    unitId: unitId ?? this.unitId,
    taxCategoryId: taxCategoryId.present
        ? taxCategoryId.value
        : this.taxCategoryId,
    sku: sku ?? this.sku,
    normalizedSku: normalizedSku ?? this.normalizedSku,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    description: description.present ? description.value : this.description,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ProductsData copyWithCompanion(ProductsCompanion data) {
    return ProductsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      taxCategoryId: data.taxCategoryId.present
          ? data.taxCategoryId.value
          : this.taxCategoryId,
      sku: data.sku.present ? data.sku.value : this.sku,
      normalizedSku: data.normalizedSku.present
          ? data.normalizedSku.value
          : this.normalizedSku,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('categoryId: $categoryId, ')
          ..write('unitId: $unitId, ')
          ..write('taxCategoryId: $taxCategoryId, ')
          ..write('sku: $sku, ')
          ..write('normalizedSku: $normalizedSku, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    categoryId,
    unitId,
    taxCategoryId,
    sku,
    normalizedSku,
    name,
    normalizedName,
    description,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.categoryId == this.categoryId &&
          other.unitId == this.unitId &&
          other.taxCategoryId == this.taxCategoryId &&
          other.sku == this.sku &&
          other.normalizedSku == this.normalizedSku &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.description == this.description &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ProductsCompanion extends UpdateCompanion<ProductsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String?> categoryId;
  final Value<String> unitId;
  final Value<String?> taxCategoryId;
  final Value<String> sku;
  final Value<String> normalizedSku;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<String?> description;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.unitId = const Value.absent(),
    this.taxCategoryId = const Value.absent(),
    this.sku = const Value.absent(),
    this.normalizedSku = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    required String organizationId,
    this.categoryId = const Value.absent(),
    required String unitId,
    this.taxCategoryId = const Value.absent(),
    required String sku,
    required String normalizedSku,
    required String name,
    required String normalizedName,
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       unitId = Value(unitId),
       sku = Value(sku),
       normalizedSku = Value(normalizedSku),
       name = Value(name),
       normalizedName = Value(normalizedName),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProductsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? categoryId,
    Expression<String>? unitId,
    Expression<String>? taxCategoryId,
    Expression<String>? sku,
    Expression<String>? normalizedSku,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<String>? description,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (categoryId != null) 'category_id': categoryId,
      if (unitId != null) 'unit_id': unitId,
      if (taxCategoryId != null) 'tax_category_id': taxCategoryId,
      if (sku != null) 'sku': sku,
      if (normalizedSku != null) 'normalized_sku': normalizedSku,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String?>? categoryId,
    Value<String>? unitId,
    Value<String?>? taxCategoryId,
    Value<String>? sku,
    Value<String>? normalizedSku,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<String?>? description,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      categoryId: categoryId ?? this.categoryId,
      unitId: unitId ?? this.unitId,
      taxCategoryId: taxCategoryId ?? this.taxCategoryId,
      sku: sku ?? this.sku,
      normalizedSku: normalizedSku ?? this.normalizedSku,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<String>(unitId.value);
    }
    if (taxCategoryId.present) {
      map['tax_category_id'] = Variable<String>(taxCategoryId.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (normalizedSku.present) {
      map['normalized_sku'] = Variable<String>(normalizedSku.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('categoryId: $categoryId, ')
          ..write('unitId: $unitId, ')
          ..write('taxCategoryId: $taxCategoryId, ')
          ..write('sku: $sku, ')
          ..write('normalizedSku: $normalizedSku, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ProductBarcodes extends Table
    with TableInfo<ProductBarcodes, ProductBarcodesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ProductBarcodes(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id) ON DELETE CASCADE',
    ),
  );
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> normalizedBarcode =
      GeneratedColumn<String>(
        'normalized_barcode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    productId,
    barcode,
    normalizedBarcode,
    isPrimary,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_barcodes';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, barcode},
    {organizationId, normalizedBarcode},
  ];
  @override
  ProductBarcodesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductBarcodesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      )!,
      normalizedBarcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_barcode'],
      )!,
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  ProductBarcodes createAlias(String alias) {
    return ProductBarcodes(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (product_id, organization_id) REFERENCES products (id, organization_id) ON DELETE CASCADE',
  ];
}

class ProductBarcodesData extends DataClass
    implements Insertable<ProductBarcodesData> {
  final String id;
  final String organizationId;
  final String productId;
  final String barcode;
  final String normalizedBarcode;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ProductBarcodesData({
    required this.id,
    required this.organizationId,
    required this.productId,
    required this.barcode,
    required this.normalizedBarcode,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['product_id'] = Variable<String>(productId);
    map['barcode'] = Variable<String>(barcode);
    map['normalized_barcode'] = Variable<String>(normalizedBarcode);
    map['is_primary'] = Variable<bool>(isPrimary);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ProductBarcodesCompanion toCompanion(bool nullToAbsent) {
    return ProductBarcodesCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      productId: Value(productId),
      barcode: Value(barcode),
      normalizedBarcode: Value(normalizedBarcode),
      isPrimary: Value(isPrimary),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ProductBarcodesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductBarcodesData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      productId: serializer.fromJson<String>(json['productId']),
      barcode: serializer.fromJson<String>(json['barcode']),
      normalizedBarcode: serializer.fromJson<String>(json['normalizedBarcode']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'productId': serializer.toJson<String>(productId),
      'barcode': serializer.toJson<String>(barcode),
      'normalizedBarcode': serializer.toJson<String>(normalizedBarcode),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ProductBarcodesData copyWith({
    String? id,
    String? organizationId,
    String? productId,
    String? barcode,
    String? normalizedBarcode,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ProductBarcodesData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    productId: productId ?? this.productId,
    barcode: barcode ?? this.barcode,
    normalizedBarcode: normalizedBarcode ?? this.normalizedBarcode,
    isPrimary: isPrimary ?? this.isPrimary,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ProductBarcodesData copyWithCompanion(ProductBarcodesCompanion data) {
    return ProductBarcodesData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      productId: data.productId.present ? data.productId.value : this.productId,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      normalizedBarcode: data.normalizedBarcode.present
          ? data.normalizedBarcode.value
          : this.normalizedBarcode,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductBarcodesData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('productId: $productId, ')
          ..write('barcode: $barcode, ')
          ..write('normalizedBarcode: $normalizedBarcode, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    productId,
    barcode,
    normalizedBarcode,
    isPrimary,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductBarcodesData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.productId == this.productId &&
          other.barcode == this.barcode &&
          other.normalizedBarcode == this.normalizedBarcode &&
          other.isPrimary == this.isPrimary &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ProductBarcodesCompanion extends UpdateCompanion<ProductBarcodesData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> productId;
  final Value<String> barcode;
  final Value<String> normalizedBarcode;
  final Value<bool> isPrimary;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ProductBarcodesCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.productId = const Value.absent(),
    this.barcode = const Value.absent(),
    this.normalizedBarcode = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductBarcodesCompanion.insert({
    required String id,
    required String organizationId,
    required String productId,
    required String barcode,
    required String normalizedBarcode,
    this.isPrimary = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       productId = Value(productId),
       barcode = Value(barcode),
       normalizedBarcode = Value(normalizedBarcode),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProductBarcodesData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? productId,
    Expression<String>? barcode,
    Expression<String>? normalizedBarcode,
    Expression<bool>? isPrimary,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (productId != null) 'product_id': productId,
      if (barcode != null) 'barcode': barcode,
      if (normalizedBarcode != null) 'normalized_barcode': normalizedBarcode,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductBarcodesCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? productId,
    Value<String>? barcode,
    Value<String>? normalizedBarcode,
    Value<bool>? isPrimary,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ProductBarcodesCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      productId: productId ?? this.productId,
      barcode: barcode ?? this.barcode,
      normalizedBarcode: normalizedBarcode ?? this.normalizedBarcode,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (normalizedBarcode.present) {
      map['normalized_barcode'] = Variable<String>(normalizedBarcode.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductBarcodesCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('productId: $productId, ')
          ..write('barcode: $barcode, ')
          ..write('normalizedBarcode: $normalizedBarcode, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ProductPrices extends Table
    with TableInfo<ProductPrices, ProductPricesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ProductPrices(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id) ON DELETE CASCADE',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchScope = GeneratedColumn<String>(
    'branch_scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> unitPriceMinor = GeneratedColumn<int>(
    'unit_price_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('unit_price_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> effectiveFrom =
      GeneratedColumn<DateTime>(
        'effective_from',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<DateTime> effectiveTo = GeneratedColumn<DateTime>(
    'effective_to',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> createdByUserId = GeneratedColumn<String>(
    'created_by_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    productId,
    branchId,
    branchScope,
    unitPriceMinor,
    effectiveFrom,
    effectiveTo,
    createdByUserId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_prices';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {productId, branchId, effectiveFrom},
    {productId, branchScope, effectiveFrom},
  ];
  @override
  ProductPricesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductPricesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      ),
      branchScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_scope'],
      )!,
      unitPriceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_minor'],
      )!,
      effectiveFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}effective_from'],
      )!,
      effectiveTo: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}effective_to'],
      ),
      createdByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_user_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  ProductPrices createAlias(String alias) {
    return ProductPrices(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (product_id, organization_id) REFERENCES products (id, organization_id) ON DELETE CASCADE',
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'CHECK ((branch_id IS NULL AND branch_scope = \'*\') OR (branch_id IS NOT NULL AND branch_scope = branch_id))',
  ];
}

class ProductPricesData extends DataClass
    implements Insertable<ProductPricesData> {
  final String id;
  final String organizationId;
  final String productId;
  final String? branchId;
  final String branchScope;
  final int unitPriceMinor;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String createdByUserId;
  final DateTime createdAt;
  const ProductPricesData({
    required this.id,
    required this.organizationId,
    required this.productId,
    this.branchId,
    required this.branchScope,
    required this.unitPriceMinor,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.createdByUserId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['product_id'] = Variable<String>(productId);
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    map['branch_scope'] = Variable<String>(branchScope);
    map['unit_price_minor'] = Variable<int>(unitPriceMinor);
    map['effective_from'] = Variable<DateTime>(effectiveFrom);
    if (!nullToAbsent || effectiveTo != null) {
      map['effective_to'] = Variable<DateTime>(effectiveTo);
    }
    map['created_by_user_id'] = Variable<String>(createdByUserId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProductPricesCompanion toCompanion(bool nullToAbsent) {
    return ProductPricesCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      productId: Value(productId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      branchScope: Value(branchScope),
      unitPriceMinor: Value(unitPriceMinor),
      effectiveFrom: Value(effectiveFrom),
      effectiveTo: effectiveTo == null && nullToAbsent
          ? const Value.absent()
          : Value(effectiveTo),
      createdByUserId: Value(createdByUserId),
      createdAt: Value(createdAt),
    );
  }

  factory ProductPricesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductPricesData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      productId: serializer.fromJson<String>(json['productId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      branchScope: serializer.fromJson<String>(json['branchScope']),
      unitPriceMinor: serializer.fromJson<int>(json['unitPriceMinor']),
      effectiveFrom: serializer.fromJson<DateTime>(json['effectiveFrom']),
      effectiveTo: serializer.fromJson<DateTime?>(json['effectiveTo']),
      createdByUserId: serializer.fromJson<String>(json['createdByUserId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'productId': serializer.toJson<String>(productId),
      'branchId': serializer.toJson<String?>(branchId),
      'branchScope': serializer.toJson<String>(branchScope),
      'unitPriceMinor': serializer.toJson<int>(unitPriceMinor),
      'effectiveFrom': serializer.toJson<DateTime>(effectiveFrom),
      'effectiveTo': serializer.toJson<DateTime?>(effectiveTo),
      'createdByUserId': serializer.toJson<String>(createdByUserId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProductPricesData copyWith({
    String? id,
    String? organizationId,
    String? productId,
    Value<String?> branchId = const Value.absent(),
    String? branchScope,
    int? unitPriceMinor,
    DateTime? effectiveFrom,
    Value<DateTime?> effectiveTo = const Value.absent(),
    String? createdByUserId,
    DateTime? createdAt,
  }) => ProductPricesData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    productId: productId ?? this.productId,
    branchId: branchId.present ? branchId.value : this.branchId,
    branchScope: branchScope ?? this.branchScope,
    unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    effectiveTo: effectiveTo.present ? effectiveTo.value : this.effectiveTo,
    createdByUserId: createdByUserId ?? this.createdByUserId,
    createdAt: createdAt ?? this.createdAt,
  );
  ProductPricesData copyWithCompanion(ProductPricesCompanion data) {
    return ProductPricesData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      productId: data.productId.present ? data.productId.value : this.productId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      branchScope: data.branchScope.present
          ? data.branchScope.value
          : this.branchScope,
      unitPriceMinor: data.unitPriceMinor.present
          ? data.unitPriceMinor.value
          : this.unitPriceMinor,
      effectiveFrom: data.effectiveFrom.present
          ? data.effectiveFrom.value
          : this.effectiveFrom,
      effectiveTo: data.effectiveTo.present
          ? data.effectiveTo.value
          : this.effectiveTo,
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductPricesData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('productId: $productId, ')
          ..write('branchId: $branchId, ')
          ..write('branchScope: $branchScope, ')
          ..write('unitPriceMinor: $unitPriceMinor, ')
          ..write('effectiveFrom: $effectiveFrom, ')
          ..write('effectiveTo: $effectiveTo, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    productId,
    branchId,
    branchScope,
    unitPriceMinor,
    effectiveFrom,
    effectiveTo,
    createdByUserId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductPricesData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.productId == this.productId &&
          other.branchId == this.branchId &&
          other.branchScope == this.branchScope &&
          other.unitPriceMinor == this.unitPriceMinor &&
          other.effectiveFrom == this.effectiveFrom &&
          other.effectiveTo == this.effectiveTo &&
          other.createdByUserId == this.createdByUserId &&
          other.createdAt == this.createdAt);
}

class ProductPricesCompanion extends UpdateCompanion<ProductPricesData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> productId;
  final Value<String?> branchId;
  final Value<String> branchScope;
  final Value<int> unitPriceMinor;
  final Value<DateTime> effectiveFrom;
  final Value<DateTime?> effectiveTo;
  final Value<String> createdByUserId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProductPricesCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.productId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.branchScope = const Value.absent(),
    this.unitPriceMinor = const Value.absent(),
    this.effectiveFrom = const Value.absent(),
    this.effectiveTo = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductPricesCompanion.insert({
    required String id,
    required String organizationId,
    required String productId,
    this.branchId = const Value.absent(),
    required String branchScope,
    required int unitPriceMinor,
    required DateTime effectiveFrom,
    this.effectiveTo = const Value.absent(),
    required String createdByUserId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       productId = Value(productId),
       branchScope = Value(branchScope),
       unitPriceMinor = Value(unitPriceMinor),
       effectiveFrom = Value(effectiveFrom),
       createdByUserId = Value(createdByUserId),
       createdAt = Value(createdAt);
  static Insertable<ProductPricesData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? productId,
    Expression<String>? branchId,
    Expression<String>? branchScope,
    Expression<int>? unitPriceMinor,
    Expression<DateTime>? effectiveFrom,
    Expression<DateTime>? effectiveTo,
    Expression<String>? createdByUserId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (productId != null) 'product_id': productId,
      if (branchId != null) 'branch_id': branchId,
      if (branchScope != null) 'branch_scope': branchScope,
      if (unitPriceMinor != null) 'unit_price_minor': unitPriceMinor,
      if (effectiveFrom != null) 'effective_from': effectiveFrom,
      if (effectiveTo != null) 'effective_to': effectiveTo,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductPricesCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? productId,
    Value<String?>? branchId,
    Value<String>? branchScope,
    Value<int>? unitPriceMinor,
    Value<DateTime>? effectiveFrom,
    Value<DateTime?>? effectiveTo,
    Value<String>? createdByUserId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProductPricesCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      productId: productId ?? this.productId,
      branchId: branchId ?? this.branchId,
      branchScope: branchScope ?? this.branchScope,
      unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (branchScope.present) {
      map['branch_scope'] = Variable<String>(branchScope.value);
    }
    if (unitPriceMinor.present) {
      map['unit_price_minor'] = Variable<int>(unitPriceMinor.value);
    }
    if (effectiveFrom.present) {
      map['effective_from'] = Variable<DateTime>(effectiveFrom.value);
    }
    if (effectiveTo.present) {
      map['effective_to'] = Variable<DateTime>(effectiveTo.value);
    }
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<String>(createdByUserId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductPricesCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('productId: $productId, ')
          ..write('branchId: $branchId, ')
          ..write('branchScope: $branchScope, ')
          ..write('unitPriceMinor: $unitPriceMinor, ')
          ..write('effectiveFrom: $effectiveFrom, ')
          ..write('effectiveTo: $effectiveTo, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ProductImages extends Table
    with TableInfo<ProductImages, ProductImagesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ProductImages(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id) ON DELETE CASCADE',
    ),
  );
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
    'remote_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> uploadStatus = GeneratedColumn<String>(
    'upload_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'pending\''),
  );
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    productId,
    localPath,
    remoteUrl,
    uploadStatus,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_images';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductImagesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductImagesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      remoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_url'],
      ),
      uploadStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_status'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  ProductImages createAlias(String alias) {
    return ProductImages(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (product_id, organization_id) REFERENCES products (id, organization_id) ON DELETE CASCADE',
  ];
}

class ProductImagesData extends DataClass
    implements Insertable<ProductImagesData> {
  final String id;
  final String organizationId;
  final String productId;
  final String? localPath;
  final String? remoteUrl;
  final String uploadStatus;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ProductImagesData({
    required this.id,
    required this.organizationId,
    required this.productId,
    this.localPath,
    this.remoteUrl,
    required this.uploadStatus,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['product_id'] = Variable<String>(productId);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || remoteUrl != null) {
      map['remote_url'] = Variable<String>(remoteUrl);
    }
    map['upload_status'] = Variable<String>(uploadStatus);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ProductImagesCompanion toCompanion(bool nullToAbsent) {
    return ProductImagesCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      productId: Value(productId),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      remoteUrl: remoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUrl),
      uploadStatus: Value(uploadStatus),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ProductImagesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductImagesData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      productId: serializer.fromJson<String>(json['productId']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      remoteUrl: serializer.fromJson<String?>(json['remoteUrl']),
      uploadStatus: serializer.fromJson<String>(json['uploadStatus']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'productId': serializer.toJson<String>(productId),
      'localPath': serializer.toJson<String?>(localPath),
      'remoteUrl': serializer.toJson<String?>(remoteUrl),
      'uploadStatus': serializer.toJson<String>(uploadStatus),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ProductImagesData copyWith({
    String? id,
    String? organizationId,
    String? productId,
    Value<String?> localPath = const Value.absent(),
    Value<String?> remoteUrl = const Value.absent(),
    String? uploadStatus,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ProductImagesData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    productId: productId ?? this.productId,
    localPath: localPath.present ? localPath.value : this.localPath,
    remoteUrl: remoteUrl.present ? remoteUrl.value : this.remoteUrl,
    uploadStatus: uploadStatus ?? this.uploadStatus,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ProductImagesData copyWithCompanion(ProductImagesCompanion data) {
    return ProductImagesData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      productId: data.productId.present ? data.productId.value : this.productId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      uploadStatus: data.uploadStatus.present
          ? data.uploadStatus.value
          : this.uploadStatus,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductImagesData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('productId: $productId, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('uploadStatus: $uploadStatus, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    productId,
    localPath,
    remoteUrl,
    uploadStatus,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductImagesData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.productId == this.productId &&
          other.localPath == this.localPath &&
          other.remoteUrl == this.remoteUrl &&
          other.uploadStatus == this.uploadStatus &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ProductImagesCompanion extends UpdateCompanion<ProductImagesData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> productId;
  final Value<String?> localPath;
  final Value<String?> remoteUrl;
  final Value<String> uploadStatus;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ProductImagesCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.productId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.uploadStatus = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductImagesCompanion.insert({
    required String id,
    required String organizationId,
    required String productId,
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.uploadStatus = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       productId = Value(productId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProductImagesData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? productId,
    Expression<String>? localPath,
    Expression<String>? remoteUrl,
    Expression<String>? uploadStatus,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (productId != null) 'product_id': productId,
      if (localPath != null) 'local_path': localPath,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (uploadStatus != null) 'upload_status': uploadStatus,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductImagesCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? productId,
    Value<String?>? localPath,
    Value<String?>? remoteUrl,
    Value<String>? uploadStatus,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ProductImagesCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      productId: productId ?? this.productId,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (uploadStatus.present) {
      map['upload_status'] = Variable<String>(uploadStatus.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductImagesCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('productId: $productId, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('uploadStatus: $uploadStatus, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class StockLocations extends Table
    with TableInfo<StockLocations, StockLocationsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  StockLocations(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> locationType = GeneratedColumn<String>(
    'location_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'warehouse\''),
  );
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('1'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    code,
    name,
    locationType,
    isDefault,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_locations';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, branchId, code},
    {id, organizationId, branchId},
  ];
  @override
  StockLocationsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockLocationsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      locationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_type'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  StockLocations createAlias(String alias) {
    return StockLocations(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'CHECK (location_type IN (\'sales_floor\', \'warehouse\', \'returns\', \'damaged\'))',
  ];
}

class StockLocationsData extends DataClass
    implements Insertable<StockLocationsData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String code;
  final String name;
  final String locationType;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const StockLocationsData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.code,
    required this.name,
    required this.locationType,
    required this.isDefault,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['location_type'] = Variable<String>(locationType);
    map['is_default'] = Variable<bool>(isDefault);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  StockLocationsCompanion toCompanion(bool nullToAbsent) {
    return StockLocationsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      code: Value(code),
      name: Value(name),
      locationType: Value(locationType),
      isDefault: Value(isDefault),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory StockLocationsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockLocationsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      locationType: serializer.fromJson<String>(json['locationType']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'locationType': serializer.toJson<String>(locationType),
      'isDefault': serializer.toJson<bool>(isDefault),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  StockLocationsData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? code,
    String? name,
    String? locationType,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => StockLocationsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    code: code ?? this.code,
    name: name ?? this.name,
    locationType: locationType ?? this.locationType,
    isDefault: isDefault ?? this.isDefault,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  StockLocationsData copyWithCompanion(StockLocationsCompanion data) {
    return StockLocationsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      locationType: data.locationType.present
          ? data.locationType.value
          : this.locationType,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockLocationsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('locationType: $locationType, ')
          ..write('isDefault: $isDefault, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    code,
    name,
    locationType,
    isDefault,
    isActive,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockLocationsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.code == this.code &&
          other.name == this.name &&
          other.locationType == this.locationType &&
          other.isDefault == this.isDefault &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class StockLocationsCompanion extends UpdateCompanion<StockLocationsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> code;
  final Value<String> name;
  final Value<String> locationType;
  final Value<bool> isDefault;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const StockLocationsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.locationType = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockLocationsCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String code,
    required String name,
    this.locationType = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       code = Value(code),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StockLocationsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? locationType,
    Expression<bool>? isDefault,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (locationType != null) 'location_type': locationType,
      if (isDefault != null) 'is_default': isDefault,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockLocationsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? code,
    Value<String>? name,
    Value<String>? locationType,
    Value<bool>? isDefault,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return StockLocationsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      code: code ?? this.code,
      name: name ?? this.name,
      locationType: locationType ?? this.locationType,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (locationType.present) {
      map['location_type'] = Variable<String>(locationType.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockLocationsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('locationType: $locationType, ')
          ..write('isDefault: $isDefault, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class InventoryTransactions extends Table
    with TableInfo<InventoryTransactions, InventoryTransactionsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  InventoryTransactions(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> transactionType = GeneratedColumn<String>(
    'transaction_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'posted\''),
  );
  late final GeneratedColumn<String> reasonCode = GeneratedColumn<String>(
    'reason_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> referenceType = GeneratedColumn<String>(
    'reference_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> referenceId = GeneratedColumn<String>(
    'reference_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> reversesTransactionId =
      GeneratedColumn<String>(
        'reverses_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES inventory_transactions (id) ON DELETE RESTRICT',
        ),
      );
  late final GeneratedColumn<bool> occurredDuringStockCount =
      GeneratedColumn<bool>(
        'occurred_during_stock_count',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("occurred_during_stock_count" IN (0, 1))',
        ),
        defaultValue: const CustomExpression('0'),
      );
  late final GeneratedColumn<String> createdByUserId = GeneratedColumn<String>(
    'created_by_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> approvedByUserId = GeneratedColumn<String>(
    'approved_by_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> approvedAt = GeneratedColumn<DateTime>(
    'approved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    operationId,
    transactionType,
    status,
    reasonCode,
    notes,
    referenceType,
    referenceId,
    reversesTransactionId,
    occurredDuringStockCount,
    createdByUserId,
    approvedByUserId,
    approvedAt,
    occurredAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_transactions';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, operationId},
    {id, organizationId, branchId},
  ];
  @override
  InventoryTransactionsData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryTransactionsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      transactionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      reasonCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_code'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      referenceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_type'],
      ),
      referenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_id'],
      ),
      reversesTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reverses_transaction_id'],
      ),
      occurredDuringStockCount: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}occurred_during_stock_count'],
      )!,
      createdByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_user_id'],
      )!,
      approvedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approved_by_user_id'],
      ),
      approvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}approved_at'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  InventoryTransactions createAlias(String alias) {
    return InventoryTransactions(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'CHECK (status IN (\'posted\', \'reversed\'))',
    'CHECK (transaction_type IN (\'opening_balance\', \'purchase_receipt\', \'sale\', \'sale_return\', \'adjustment_increase\', \'adjustment_decrease\', \'transfer_shipment\', \'transfer_receipt\', \'stock_count_correction\', \'reversal\'))',
  ];
}

class InventoryTransactionsData extends DataClass
    implements Insertable<InventoryTransactionsData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String operationId;
  final String transactionType;
  final String status;
  final String? reasonCode;
  final String? notes;
  final String? referenceType;
  final String? referenceId;
  final String? reversesTransactionId;
  final bool occurredDuringStockCount;
  final String createdByUserId;
  final String? approvedByUserId;
  final DateTime? approvedAt;
  final DateTime occurredAt;
  final DateTime createdAt;
  const InventoryTransactionsData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.operationId,
    required this.transactionType,
    required this.status,
    this.reasonCode,
    this.notes,
    this.referenceType,
    this.referenceId,
    this.reversesTransactionId,
    required this.occurredDuringStockCount,
    required this.createdByUserId,
    this.approvedByUserId,
    this.approvedAt,
    required this.occurredAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['operation_id'] = Variable<String>(operationId);
    map['transaction_type'] = Variable<String>(transactionType);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || reasonCode != null) {
      map['reason_code'] = Variable<String>(reasonCode);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || referenceType != null) {
      map['reference_type'] = Variable<String>(referenceType);
    }
    if (!nullToAbsent || referenceId != null) {
      map['reference_id'] = Variable<String>(referenceId);
    }
    if (!nullToAbsent || reversesTransactionId != null) {
      map['reverses_transaction_id'] = Variable<String>(reversesTransactionId);
    }
    map['occurred_during_stock_count'] = Variable<bool>(
      occurredDuringStockCount,
    );
    map['created_by_user_id'] = Variable<String>(createdByUserId);
    if (!nullToAbsent || approvedByUserId != null) {
      map['approved_by_user_id'] = Variable<String>(approvedByUserId);
    }
    if (!nullToAbsent || approvedAt != null) {
      map['approved_at'] = Variable<DateTime>(approvedAt);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  InventoryTransactionsCompanion toCompanion(bool nullToAbsent) {
    return InventoryTransactionsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      operationId: Value(operationId),
      transactionType: Value(transactionType),
      status: Value(status),
      reasonCode: reasonCode == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonCode),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      referenceType: referenceType == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceType),
      referenceId: referenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceId),
      reversesTransactionId: reversesTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(reversesTransactionId),
      occurredDuringStockCount: Value(occurredDuringStockCount),
      createdByUserId: Value(createdByUserId),
      approvedByUserId: approvedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedByUserId),
      approvedAt: approvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedAt),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
    );
  }

  factory InventoryTransactionsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryTransactionsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      transactionType: serializer.fromJson<String>(json['transactionType']),
      status: serializer.fromJson<String>(json['status']),
      reasonCode: serializer.fromJson<String?>(json['reasonCode']),
      notes: serializer.fromJson<String?>(json['notes']),
      referenceType: serializer.fromJson<String?>(json['referenceType']),
      referenceId: serializer.fromJson<String?>(json['referenceId']),
      reversesTransactionId: serializer.fromJson<String?>(
        json['reversesTransactionId'],
      ),
      occurredDuringStockCount: serializer.fromJson<bool>(
        json['occurredDuringStockCount'],
      ),
      createdByUserId: serializer.fromJson<String>(json['createdByUserId']),
      approvedByUserId: serializer.fromJson<String?>(json['approvedByUserId']),
      approvedAt: serializer.fromJson<DateTime?>(json['approvedAt']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'operationId': serializer.toJson<String>(operationId),
      'transactionType': serializer.toJson<String>(transactionType),
      'status': serializer.toJson<String>(status),
      'reasonCode': serializer.toJson<String?>(reasonCode),
      'notes': serializer.toJson<String?>(notes),
      'referenceType': serializer.toJson<String?>(referenceType),
      'referenceId': serializer.toJson<String?>(referenceId),
      'reversesTransactionId': serializer.toJson<String?>(
        reversesTransactionId,
      ),
      'occurredDuringStockCount': serializer.toJson<bool>(
        occurredDuringStockCount,
      ),
      'createdByUserId': serializer.toJson<String>(createdByUserId),
      'approvedByUserId': serializer.toJson<String?>(approvedByUserId),
      'approvedAt': serializer.toJson<DateTime?>(approvedAt),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  InventoryTransactionsData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? operationId,
    String? transactionType,
    String? status,
    Value<String?> reasonCode = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> referenceType = const Value.absent(),
    Value<String?> referenceId = const Value.absent(),
    Value<String?> reversesTransactionId = const Value.absent(),
    bool? occurredDuringStockCount,
    String? createdByUserId,
    Value<String?> approvedByUserId = const Value.absent(),
    Value<DateTime?> approvedAt = const Value.absent(),
    DateTime? occurredAt,
    DateTime? createdAt,
  }) => InventoryTransactionsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    operationId: operationId ?? this.operationId,
    transactionType: transactionType ?? this.transactionType,
    status: status ?? this.status,
    reasonCode: reasonCode.present ? reasonCode.value : this.reasonCode,
    notes: notes.present ? notes.value : this.notes,
    referenceType: referenceType.present
        ? referenceType.value
        : this.referenceType,
    referenceId: referenceId.present ? referenceId.value : this.referenceId,
    reversesTransactionId: reversesTransactionId.present
        ? reversesTransactionId.value
        : this.reversesTransactionId,
    occurredDuringStockCount:
        occurredDuringStockCount ?? this.occurredDuringStockCount,
    createdByUserId: createdByUserId ?? this.createdByUserId,
    approvedByUserId: approvedByUserId.present
        ? approvedByUserId.value
        : this.approvedByUserId,
    approvedAt: approvedAt.present ? approvedAt.value : this.approvedAt,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt ?? this.createdAt,
  );
  InventoryTransactionsData copyWithCompanion(
    InventoryTransactionsCompanion data,
  ) {
    return InventoryTransactionsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      transactionType: data.transactionType.present
          ? data.transactionType.value
          : this.transactionType,
      status: data.status.present ? data.status.value : this.status,
      reasonCode: data.reasonCode.present
          ? data.reasonCode.value
          : this.reasonCode,
      notes: data.notes.present ? data.notes.value : this.notes,
      referenceType: data.referenceType.present
          ? data.referenceType.value
          : this.referenceType,
      referenceId: data.referenceId.present
          ? data.referenceId.value
          : this.referenceId,
      reversesTransactionId: data.reversesTransactionId.present
          ? data.reversesTransactionId.value
          : this.reversesTransactionId,
      occurredDuringStockCount: data.occurredDuringStockCount.present
          ? data.occurredDuringStockCount.value
          : this.occurredDuringStockCount,
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
      approvedByUserId: data.approvedByUserId.present
          ? data.approvedByUserId.value
          : this.approvedByUserId,
      approvedAt: data.approvedAt.present
          ? data.approvedAt.value
          : this.approvedAt,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryTransactionsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('operationId: $operationId, ')
          ..write('transactionType: $transactionType, ')
          ..write('status: $status, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('notes: $notes, ')
          ..write('referenceType: $referenceType, ')
          ..write('referenceId: $referenceId, ')
          ..write('reversesTransactionId: $reversesTransactionId, ')
          ..write('occurredDuringStockCount: $occurredDuringStockCount, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('approvedByUserId: $approvedByUserId, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    operationId,
    transactionType,
    status,
    reasonCode,
    notes,
    referenceType,
    referenceId,
    reversesTransactionId,
    occurredDuringStockCount,
    createdByUserId,
    approvedByUserId,
    approvedAt,
    occurredAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryTransactionsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.operationId == this.operationId &&
          other.transactionType == this.transactionType &&
          other.status == this.status &&
          other.reasonCode == this.reasonCode &&
          other.notes == this.notes &&
          other.referenceType == this.referenceType &&
          other.referenceId == this.referenceId &&
          other.reversesTransactionId == this.reversesTransactionId &&
          other.occurredDuringStockCount == this.occurredDuringStockCount &&
          other.createdByUserId == this.createdByUserId &&
          other.approvedByUserId == this.approvedByUserId &&
          other.approvedAt == this.approvedAt &&
          other.occurredAt == this.occurredAt &&
          other.createdAt == this.createdAt);
}

class InventoryTransactionsCompanion
    extends UpdateCompanion<InventoryTransactionsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> operationId;
  final Value<String> transactionType;
  final Value<String> status;
  final Value<String?> reasonCode;
  final Value<String?> notes;
  final Value<String?> referenceType;
  final Value<String?> referenceId;
  final Value<String?> reversesTransactionId;
  final Value<bool> occurredDuringStockCount;
  final Value<String> createdByUserId;
  final Value<String?> approvedByUserId;
  final Value<DateTime?> approvedAt;
  final Value<DateTime> occurredAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const InventoryTransactionsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.transactionType = const Value.absent(),
    this.status = const Value.absent(),
    this.reasonCode = const Value.absent(),
    this.notes = const Value.absent(),
    this.referenceType = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.reversesTransactionId = const Value.absent(),
    this.occurredDuringStockCount = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.approvedByUserId = const Value.absent(),
    this.approvedAt = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryTransactionsCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String operationId,
    required String transactionType,
    this.status = const Value.absent(),
    this.reasonCode = const Value.absent(),
    this.notes = const Value.absent(),
    this.referenceType = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.reversesTransactionId = const Value.absent(),
    this.occurredDuringStockCount = const Value.absent(),
    required String createdByUserId,
    this.approvedByUserId = const Value.absent(),
    this.approvedAt = const Value.absent(),
    required DateTime occurredAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       operationId = Value(operationId),
       transactionType = Value(transactionType),
       createdByUserId = Value(createdByUserId),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt);
  static Insertable<InventoryTransactionsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? operationId,
    Expression<String>? transactionType,
    Expression<String>? status,
    Expression<String>? reasonCode,
    Expression<String>? notes,
    Expression<String>? referenceType,
    Expression<String>? referenceId,
    Expression<String>? reversesTransactionId,
    Expression<bool>? occurredDuringStockCount,
    Expression<String>? createdByUserId,
    Expression<String>? approvedByUserId,
    Expression<DateTime>? approvedAt,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (operationId != null) 'operation_id': operationId,
      if (transactionType != null) 'transaction_type': transactionType,
      if (status != null) 'status': status,
      if (reasonCode != null) 'reason_code': reasonCode,
      if (notes != null) 'notes': notes,
      if (referenceType != null) 'reference_type': referenceType,
      if (referenceId != null) 'reference_id': referenceId,
      if (reversesTransactionId != null)
        'reverses_transaction_id': reversesTransactionId,
      if (occurredDuringStockCount != null)
        'occurred_during_stock_count': occurredDuringStockCount,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      if (approvedByUserId != null) 'approved_by_user_id': approvedByUserId,
      if (approvedAt != null) 'approved_at': approvedAt,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? operationId,
    Value<String>? transactionType,
    Value<String>? status,
    Value<String?>? reasonCode,
    Value<String?>? notes,
    Value<String?>? referenceType,
    Value<String?>? referenceId,
    Value<String?>? reversesTransactionId,
    Value<bool>? occurredDuringStockCount,
    Value<String>? createdByUserId,
    Value<String?>? approvedByUserId,
    Value<DateTime?>? approvedAt,
    Value<DateTime>? occurredAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return InventoryTransactionsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      operationId: operationId ?? this.operationId,
      transactionType: transactionType ?? this.transactionType,
      status: status ?? this.status,
      reasonCode: reasonCode ?? this.reasonCode,
      notes: notes ?? this.notes,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      reversesTransactionId:
          reversesTransactionId ?? this.reversesTransactionId,
      occurredDuringStockCount:
          occurredDuringStockCount ?? this.occurredDuringStockCount,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedAt: approvedAt ?? this.approvedAt,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (transactionType.present) {
      map['transaction_type'] = Variable<String>(transactionType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (reasonCode.present) {
      map['reason_code'] = Variable<String>(reasonCode.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (referenceType.present) {
      map['reference_type'] = Variable<String>(referenceType.value);
    }
    if (referenceId.present) {
      map['reference_id'] = Variable<String>(referenceId.value);
    }
    if (reversesTransactionId.present) {
      map['reverses_transaction_id'] = Variable<String>(
        reversesTransactionId.value,
      );
    }
    if (occurredDuringStockCount.present) {
      map['occurred_during_stock_count'] = Variable<bool>(
        occurredDuringStockCount.value,
      );
    }
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<String>(createdByUserId.value);
    }
    if (approvedByUserId.present) {
      map['approved_by_user_id'] = Variable<String>(approvedByUserId.value);
    }
    if (approvedAt.present) {
      map['approved_at'] = Variable<DateTime>(approvedAt.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('operationId: $operationId, ')
          ..write('transactionType: $transactionType, ')
          ..write('status: $status, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('notes: $notes, ')
          ..write('referenceType: $referenceType, ')
          ..write('referenceId: $referenceId, ')
          ..write('reversesTransactionId: $reversesTransactionId, ')
          ..write('occurredDuringStockCount: $occurredDuringStockCount, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('approvedByUserId: $approvedByUserId, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class InventoryLedgerEntries extends Table
    with TableInfo<InventoryLedgerEntries, InventoryLedgerEntriesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  InventoryLedgerEntries(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES inventory_transactions (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> stockLocationId = GeneratedColumn<String>(
    'stock_location_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_locations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<int> quantityDeltaMilli = GeneratedColumn<int>(
    'quantity_delta_milli',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('quantity_delta_milli <> 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> balanceAfterMilli = GeneratedColumn<int>(
    'balance_after_milli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    transactionId,
    stockLocationId,
    productId,
    quantityDeltaMilli,
    balanceAfterMilli,
    occurredAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_ledger_entries';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {transactionId, stockLocationId, productId},
  ];
  @override
  InventoryLedgerEntriesData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryLedgerEntriesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      )!,
      stockLocationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stock_location_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      quantityDeltaMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity_delta_milli'],
      )!,
      balanceAfterMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_after_milli'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  InventoryLedgerEntries createAlias(String alias) {
    return InventoryLedgerEntries(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (transaction_id, organization_id, branch_id) REFERENCES inventory_transactions (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (stock_location_id, organization_id, branch_id) REFERENCES stock_locations (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) REFERENCES products (id, organization_id) ON DELETE RESTRICT',
  ];
}

class InventoryLedgerEntriesData extends DataClass
    implements Insertable<InventoryLedgerEntriesData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String transactionId;
  final String stockLocationId;
  final String productId;
  final int quantityDeltaMilli;
  final int balanceAfterMilli;
  final DateTime occurredAt;
  final DateTime createdAt;
  const InventoryLedgerEntriesData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.transactionId,
    required this.stockLocationId,
    required this.productId,
    required this.quantityDeltaMilli,
    required this.balanceAfterMilli,
    required this.occurredAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['transaction_id'] = Variable<String>(transactionId);
    map['stock_location_id'] = Variable<String>(stockLocationId);
    map['product_id'] = Variable<String>(productId);
    map['quantity_delta_milli'] = Variable<int>(quantityDeltaMilli);
    map['balance_after_milli'] = Variable<int>(balanceAfterMilli);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  InventoryLedgerEntriesCompanion toCompanion(bool nullToAbsent) {
    return InventoryLedgerEntriesCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      transactionId: Value(transactionId),
      stockLocationId: Value(stockLocationId),
      productId: Value(productId),
      quantityDeltaMilli: Value(quantityDeltaMilli),
      balanceAfterMilli: Value(balanceAfterMilli),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
    );
  }

  factory InventoryLedgerEntriesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryLedgerEntriesData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      transactionId: serializer.fromJson<String>(json['transactionId']),
      stockLocationId: serializer.fromJson<String>(json['stockLocationId']),
      productId: serializer.fromJson<String>(json['productId']),
      quantityDeltaMilli: serializer.fromJson<int>(json['quantityDeltaMilli']),
      balanceAfterMilli: serializer.fromJson<int>(json['balanceAfterMilli']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'transactionId': serializer.toJson<String>(transactionId),
      'stockLocationId': serializer.toJson<String>(stockLocationId),
      'productId': serializer.toJson<String>(productId),
      'quantityDeltaMilli': serializer.toJson<int>(quantityDeltaMilli),
      'balanceAfterMilli': serializer.toJson<int>(balanceAfterMilli),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  InventoryLedgerEntriesData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? transactionId,
    String? stockLocationId,
    String? productId,
    int? quantityDeltaMilli,
    int? balanceAfterMilli,
    DateTime? occurredAt,
    DateTime? createdAt,
  }) => InventoryLedgerEntriesData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    transactionId: transactionId ?? this.transactionId,
    stockLocationId: stockLocationId ?? this.stockLocationId,
    productId: productId ?? this.productId,
    quantityDeltaMilli: quantityDeltaMilli ?? this.quantityDeltaMilli,
    balanceAfterMilli: balanceAfterMilli ?? this.balanceAfterMilli,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt ?? this.createdAt,
  );
  InventoryLedgerEntriesData copyWithCompanion(
    InventoryLedgerEntriesCompanion data,
  ) {
    return InventoryLedgerEntriesData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      stockLocationId: data.stockLocationId.present
          ? data.stockLocationId.value
          : this.stockLocationId,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantityDeltaMilli: data.quantityDeltaMilli.present
          ? data.quantityDeltaMilli.value
          : this.quantityDeltaMilli,
      balanceAfterMilli: data.balanceAfterMilli.present
          ? data.balanceAfterMilli.value
          : this.balanceAfterMilli,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryLedgerEntriesData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('transactionId: $transactionId, ')
          ..write('stockLocationId: $stockLocationId, ')
          ..write('productId: $productId, ')
          ..write('quantityDeltaMilli: $quantityDeltaMilli, ')
          ..write('balanceAfterMilli: $balanceAfterMilli, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    transactionId,
    stockLocationId,
    productId,
    quantityDeltaMilli,
    balanceAfterMilli,
    occurredAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryLedgerEntriesData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.transactionId == this.transactionId &&
          other.stockLocationId == this.stockLocationId &&
          other.productId == this.productId &&
          other.quantityDeltaMilli == this.quantityDeltaMilli &&
          other.balanceAfterMilli == this.balanceAfterMilli &&
          other.occurredAt == this.occurredAt &&
          other.createdAt == this.createdAt);
}

class InventoryLedgerEntriesCompanion
    extends UpdateCompanion<InventoryLedgerEntriesData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> transactionId;
  final Value<String> stockLocationId;
  final Value<String> productId;
  final Value<int> quantityDeltaMilli;
  final Value<int> balanceAfterMilli;
  final Value<DateTime> occurredAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const InventoryLedgerEntriesCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.stockLocationId = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantityDeltaMilli = const Value.absent(),
    this.balanceAfterMilli = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryLedgerEntriesCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String transactionId,
    required String stockLocationId,
    required String productId,
    required int quantityDeltaMilli,
    required int balanceAfterMilli,
    required DateTime occurredAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       transactionId = Value(transactionId),
       stockLocationId = Value(stockLocationId),
       productId = Value(productId),
       quantityDeltaMilli = Value(quantityDeltaMilli),
       balanceAfterMilli = Value(balanceAfterMilli),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt);
  static Insertable<InventoryLedgerEntriesData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? transactionId,
    Expression<String>? stockLocationId,
    Expression<String>? productId,
    Expression<int>? quantityDeltaMilli,
    Expression<int>? balanceAfterMilli,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      if (productId != null) 'product_id': productId,
      if (quantityDeltaMilli != null)
        'quantity_delta_milli': quantityDeltaMilli,
      if (balanceAfterMilli != null) 'balance_after_milli': balanceAfterMilli,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryLedgerEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? transactionId,
    Value<String>? stockLocationId,
    Value<String>? productId,
    Value<int>? quantityDeltaMilli,
    Value<int>? balanceAfterMilli,
    Value<DateTime>? occurredAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return InventoryLedgerEntriesCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      transactionId: transactionId ?? this.transactionId,
      stockLocationId: stockLocationId ?? this.stockLocationId,
      productId: productId ?? this.productId,
      quantityDeltaMilli: quantityDeltaMilli ?? this.quantityDeltaMilli,
      balanceAfterMilli: balanceAfterMilli ?? this.balanceAfterMilli,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (stockLocationId.present) {
      map['stock_location_id'] = Variable<String>(stockLocationId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (quantityDeltaMilli.present) {
      map['quantity_delta_milli'] = Variable<int>(quantityDeltaMilli.value);
    }
    if (balanceAfterMilli.present) {
      map['balance_after_milli'] = Variable<int>(balanceAfterMilli.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryLedgerEntriesCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('transactionId: $transactionId, ')
          ..write('stockLocationId: $stockLocationId, ')
          ..write('productId: $productId, ')
          ..write('quantityDeltaMilli: $quantityDeltaMilli, ')
          ..write('balanceAfterMilli: $balanceAfterMilli, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class InventoryBalances extends Table
    with TableInfo<InventoryBalances, InventoryBalancesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  InventoryBalances(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> stockLocationId = GeneratedColumn<String>(
    'stock_location_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_locations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<int> onHandMilli = GeneratedColumn<int>(
    'on_hand_milli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<int> reservedMilli = GeneratedColumn<int>(
    'reserved_milli',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('reserved_milli >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<int> reorderPointMilli = GeneratedColumn<int>(
    'reorder_point_milli',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('reorder_point_milli >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('version >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    stockLocationId,
    productId,
    onHandMilli,
    reservedMilli,
    reorderPointMilli,
    version,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_balances';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, branchId, stockLocationId, productId},
  ];
  @override
  InventoryBalancesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryBalancesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      stockLocationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stock_location_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      onHandMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}on_hand_milli'],
      )!,
      reservedMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reserved_milli'],
      )!,
      reorderPointMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reorder_point_milli'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  InventoryBalances createAlias(String alias) {
    return InventoryBalances(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (stock_location_id, organization_id, branch_id) REFERENCES stock_locations (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) REFERENCES products (id, organization_id) ON DELETE RESTRICT',
  ];
}

class InventoryBalancesData extends DataClass
    implements Insertable<InventoryBalancesData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String stockLocationId;
  final String productId;
  final int onHandMilli;
  final int reservedMilli;
  final int reorderPointMilli;
  final int version;
  final DateTime updatedAt;
  const InventoryBalancesData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.stockLocationId,
    required this.productId,
    required this.onHandMilli,
    required this.reservedMilli,
    required this.reorderPointMilli,
    required this.version,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['stock_location_id'] = Variable<String>(stockLocationId);
    map['product_id'] = Variable<String>(productId);
    map['on_hand_milli'] = Variable<int>(onHandMilli);
    map['reserved_milli'] = Variable<int>(reservedMilli);
    map['reorder_point_milli'] = Variable<int>(reorderPointMilli);
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  InventoryBalancesCompanion toCompanion(bool nullToAbsent) {
    return InventoryBalancesCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      stockLocationId: Value(stockLocationId),
      productId: Value(productId),
      onHandMilli: Value(onHandMilli),
      reservedMilli: Value(reservedMilli),
      reorderPointMilli: Value(reorderPointMilli),
      version: Value(version),
      updatedAt: Value(updatedAt),
    );
  }

  factory InventoryBalancesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryBalancesData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      stockLocationId: serializer.fromJson<String>(json['stockLocationId']),
      productId: serializer.fromJson<String>(json['productId']),
      onHandMilli: serializer.fromJson<int>(json['onHandMilli']),
      reservedMilli: serializer.fromJson<int>(json['reservedMilli']),
      reorderPointMilli: serializer.fromJson<int>(json['reorderPointMilli']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'stockLocationId': serializer.toJson<String>(stockLocationId),
      'productId': serializer.toJson<String>(productId),
      'onHandMilli': serializer.toJson<int>(onHandMilli),
      'reservedMilli': serializer.toJson<int>(reservedMilli),
      'reorderPointMilli': serializer.toJson<int>(reorderPointMilli),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  InventoryBalancesData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? stockLocationId,
    String? productId,
    int? onHandMilli,
    int? reservedMilli,
    int? reorderPointMilli,
    int? version,
    DateTime? updatedAt,
  }) => InventoryBalancesData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    stockLocationId: stockLocationId ?? this.stockLocationId,
    productId: productId ?? this.productId,
    onHandMilli: onHandMilli ?? this.onHandMilli,
    reservedMilli: reservedMilli ?? this.reservedMilli,
    reorderPointMilli: reorderPointMilli ?? this.reorderPointMilli,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  InventoryBalancesData copyWithCompanion(InventoryBalancesCompanion data) {
    return InventoryBalancesData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      stockLocationId: data.stockLocationId.present
          ? data.stockLocationId.value
          : this.stockLocationId,
      productId: data.productId.present ? data.productId.value : this.productId,
      onHandMilli: data.onHandMilli.present
          ? data.onHandMilli.value
          : this.onHandMilli,
      reservedMilli: data.reservedMilli.present
          ? data.reservedMilli.value
          : this.reservedMilli,
      reorderPointMilli: data.reorderPointMilli.present
          ? data.reorderPointMilli.value
          : this.reorderPointMilli,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryBalancesData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('stockLocationId: $stockLocationId, ')
          ..write('productId: $productId, ')
          ..write('onHandMilli: $onHandMilli, ')
          ..write('reservedMilli: $reservedMilli, ')
          ..write('reorderPointMilli: $reorderPointMilli, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    stockLocationId,
    productId,
    onHandMilli,
    reservedMilli,
    reorderPointMilli,
    version,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryBalancesData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.stockLocationId == this.stockLocationId &&
          other.productId == this.productId &&
          other.onHandMilli == this.onHandMilli &&
          other.reservedMilli == this.reservedMilli &&
          other.reorderPointMilli == this.reorderPointMilli &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt);
}

class InventoryBalancesCompanion
    extends UpdateCompanion<InventoryBalancesData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> stockLocationId;
  final Value<String> productId;
  final Value<int> onHandMilli;
  final Value<int> reservedMilli;
  final Value<int> reorderPointMilli;
  final Value<int> version;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const InventoryBalancesCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.stockLocationId = const Value.absent(),
    this.productId = const Value.absent(),
    this.onHandMilli = const Value.absent(),
    this.reservedMilli = const Value.absent(),
    this.reorderPointMilli = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryBalancesCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String stockLocationId,
    required String productId,
    this.onHandMilli = const Value.absent(),
    this.reservedMilli = const Value.absent(),
    this.reorderPointMilli = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       stockLocationId = Value(stockLocationId),
       productId = Value(productId),
       updatedAt = Value(updatedAt);
  static Insertable<InventoryBalancesData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? stockLocationId,
    Expression<String>? productId,
    Expression<int>? onHandMilli,
    Expression<int>? reservedMilli,
    Expression<int>? reorderPointMilli,
    Expression<int>? version,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      if (productId != null) 'product_id': productId,
      if (onHandMilli != null) 'on_hand_milli': onHandMilli,
      if (reservedMilli != null) 'reserved_milli': reservedMilli,
      if (reorderPointMilli != null) 'reorder_point_milli': reorderPointMilli,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryBalancesCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? stockLocationId,
    Value<String>? productId,
    Value<int>? onHandMilli,
    Value<int>? reservedMilli,
    Value<int>? reorderPointMilli,
    Value<int>? version,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return InventoryBalancesCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      stockLocationId: stockLocationId ?? this.stockLocationId,
      productId: productId ?? this.productId,
      onHandMilli: onHandMilli ?? this.onHandMilli,
      reservedMilli: reservedMilli ?? this.reservedMilli,
      reorderPointMilli: reorderPointMilli ?? this.reorderPointMilli,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (stockLocationId.present) {
      map['stock_location_id'] = Variable<String>(stockLocationId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (onHandMilli.present) {
      map['on_hand_milli'] = Variable<int>(onHandMilli.value);
    }
    if (reservedMilli.present) {
      map['reserved_milli'] = Variable<int>(reservedMilli.value);
    }
    if (reorderPointMilli.present) {
      map['reorder_point_milli'] = Variable<int>(reorderPointMilli.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryBalancesCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('stockLocationId: $stockLocationId, ')
          ..write('productId: $productId, ')
          ..write('onHandMilli: $onHandMilli, ')
          ..write('reservedMilli: $reservedMilli, ')
          ..write('reorderPointMilli: $reorderPointMilli, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class StockCounts extends Table with TableInfo<StockCounts, StockCountsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  StockCounts(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> stockLocationId = GeneratedColumn<String>(
    'stock_location_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_locations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> completionOperationId =
      GeneratedColumn<String>(
        'completion_operation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<String> countType = GeneratedColumn<String>(
    'count_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'in_progress\''),
  );
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> startedByUserId = GeneratedColumn<String>(
    'started_by_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> completedByUserId =
      GeneratedColumn<String>(
        'completed_by_user_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('version >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    stockLocationId,
    operationId,
    completionOperationId,
    countType,
    status,
    notes,
    startedByUserId,
    startedAt,
    completedByUserId,
    completedAt,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_counts';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, operationId},
    {organizationId, completionOperationId},
    {id, organizationId},
    {id, organizationId, branchId},
  ];
  @override
  StockCountsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockCountsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      stockLocationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stock_location_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      completionOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completion_operation_id'],
      ),
      countType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}count_type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      startedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_by_user_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_by_user_id'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  StockCounts createAlias(String alias) {
    return StockCounts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (stock_location_id, organization_id, branch_id) REFERENCES stock_locations (id, organization_id, branch_id) ON DELETE RESTRICT',
    'CHECK (count_type IN (\'full\', \'cycle\'))',
    'CHECK (status IN (\'in_progress\', \'completed\', \'cancelled\'))',
  ];
}

class StockCountsData extends DataClass implements Insertable<StockCountsData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String stockLocationId;
  final String operationId;
  final String? completionOperationId;
  final String countType;
  final String status;
  final String? notes;
  final String startedByUserId;
  final DateTime startedAt;
  final String? completedByUserId;
  final DateTime? completedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StockCountsData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.stockLocationId,
    required this.operationId,
    this.completionOperationId,
    required this.countType,
    required this.status,
    this.notes,
    required this.startedByUserId,
    required this.startedAt,
    this.completedByUserId,
    this.completedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['stock_location_id'] = Variable<String>(stockLocationId);
    map['operation_id'] = Variable<String>(operationId);
    if (!nullToAbsent || completionOperationId != null) {
      map['completion_operation_id'] = Variable<String>(completionOperationId);
    }
    map['count_type'] = Variable<String>(countType);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['started_by_user_id'] = Variable<String>(startedByUserId);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedByUserId != null) {
      map['completed_by_user_id'] = Variable<String>(completedByUserId);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StockCountsCompanion toCompanion(bool nullToAbsent) {
    return StockCountsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      stockLocationId: Value(stockLocationId),
      operationId: Value(operationId),
      completionOperationId: completionOperationId == null && nullToAbsent
          ? const Value.absent()
          : Value(completionOperationId),
      countType: Value(countType),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      startedByUserId: Value(startedByUserId),
      startedAt: Value(startedAt),
      completedByUserId: completedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(completedByUserId),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StockCountsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockCountsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      stockLocationId: serializer.fromJson<String>(json['stockLocationId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      completionOperationId: serializer.fromJson<String?>(
        json['completionOperationId'],
      ),
      countType: serializer.fromJson<String>(json['countType']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      startedByUserId: serializer.fromJson<String>(json['startedByUserId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedByUserId: serializer.fromJson<String?>(
        json['completedByUserId'],
      ),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'stockLocationId': serializer.toJson<String>(stockLocationId),
      'operationId': serializer.toJson<String>(operationId),
      'completionOperationId': serializer.toJson<String?>(
        completionOperationId,
      ),
      'countType': serializer.toJson<String>(countType),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'startedByUserId': serializer.toJson<String>(startedByUserId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedByUserId': serializer.toJson<String?>(completedByUserId),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StockCountsData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? stockLocationId,
    String? operationId,
    Value<String?> completionOperationId = const Value.absent(),
    String? countType,
    String? status,
    Value<String?> notes = const Value.absent(),
    String? startedByUserId,
    DateTime? startedAt,
    Value<String?> completedByUserId = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StockCountsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    stockLocationId: stockLocationId ?? this.stockLocationId,
    operationId: operationId ?? this.operationId,
    completionOperationId: completionOperationId.present
        ? completionOperationId.value
        : this.completionOperationId,
    countType: countType ?? this.countType,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    startedByUserId: startedByUserId ?? this.startedByUserId,
    startedAt: startedAt ?? this.startedAt,
    completedByUserId: completedByUserId.present
        ? completedByUserId.value
        : this.completedByUserId,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StockCountsData copyWithCompanion(StockCountsCompanion data) {
    return StockCountsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      stockLocationId: data.stockLocationId.present
          ? data.stockLocationId.value
          : this.stockLocationId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      completionOperationId: data.completionOperationId.present
          ? data.completionOperationId.value
          : this.completionOperationId,
      countType: data.countType.present ? data.countType.value : this.countType,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      startedByUserId: data.startedByUserId.present
          ? data.startedByUserId.value
          : this.startedByUserId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedByUserId: data.completedByUserId.present
          ? data.completedByUserId.value
          : this.completedByUserId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockCountsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('stockLocationId: $stockLocationId, ')
          ..write('operationId: $operationId, ')
          ..write('completionOperationId: $completionOperationId, ')
          ..write('countType: $countType, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('startedByUserId: $startedByUserId, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedByUserId: $completedByUserId, ')
          ..write('completedAt: $completedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    stockLocationId,
    operationId,
    completionOperationId,
    countType,
    status,
    notes,
    startedByUserId,
    startedAt,
    completedByUserId,
    completedAt,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockCountsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.stockLocationId == this.stockLocationId &&
          other.operationId == this.operationId &&
          other.completionOperationId == this.completionOperationId &&
          other.countType == this.countType &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.startedByUserId == this.startedByUserId &&
          other.startedAt == this.startedAt &&
          other.completedByUserId == this.completedByUserId &&
          other.completedAt == this.completedAt &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StockCountsCompanion extends UpdateCompanion<StockCountsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> stockLocationId;
  final Value<String> operationId;
  final Value<String?> completionOperationId;
  final Value<String> countType;
  final Value<String> status;
  final Value<String?> notes;
  final Value<String> startedByUserId;
  final Value<DateTime> startedAt;
  final Value<String?> completedByUserId;
  final Value<DateTime?> completedAt;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StockCountsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.stockLocationId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.completionOperationId = const Value.absent(),
    this.countType = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.startedByUserId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedByUserId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockCountsCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String stockLocationId,
    required String operationId,
    this.completionOperationId = const Value.absent(),
    required String countType,
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    required String startedByUserId,
    required DateTime startedAt,
    this.completedByUserId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       stockLocationId = Value(stockLocationId),
       operationId = Value(operationId),
       countType = Value(countType),
       startedByUserId = Value(startedByUserId),
       startedAt = Value(startedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StockCountsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? stockLocationId,
    Expression<String>? operationId,
    Expression<String>? completionOperationId,
    Expression<String>? countType,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<String>? startedByUserId,
    Expression<DateTime>? startedAt,
    Expression<String>? completedByUserId,
    Expression<DateTime>? completedAt,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      if (operationId != null) 'operation_id': operationId,
      if (completionOperationId != null)
        'completion_operation_id': completionOperationId,
      if (countType != null) 'count_type': countType,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (startedByUserId != null) 'started_by_user_id': startedByUserId,
      if (startedAt != null) 'started_at': startedAt,
      if (completedByUserId != null) 'completed_by_user_id': completedByUserId,
      if (completedAt != null) 'completed_at': completedAt,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockCountsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? stockLocationId,
    Value<String>? operationId,
    Value<String?>? completionOperationId,
    Value<String>? countType,
    Value<String>? status,
    Value<String?>? notes,
    Value<String>? startedByUserId,
    Value<DateTime>? startedAt,
    Value<String?>? completedByUserId,
    Value<DateTime?>? completedAt,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StockCountsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      stockLocationId: stockLocationId ?? this.stockLocationId,
      operationId: operationId ?? this.operationId,
      completionOperationId:
          completionOperationId ?? this.completionOperationId,
      countType: countType ?? this.countType,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      startedByUserId: startedByUserId ?? this.startedByUserId,
      startedAt: startedAt ?? this.startedAt,
      completedByUserId: completedByUserId ?? this.completedByUserId,
      completedAt: completedAt ?? this.completedAt,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (stockLocationId.present) {
      map['stock_location_id'] = Variable<String>(stockLocationId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (completionOperationId.present) {
      map['completion_operation_id'] = Variable<String>(
        completionOperationId.value,
      );
    }
    if (countType.present) {
      map['count_type'] = Variable<String>(countType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (startedByUserId.present) {
      map['started_by_user_id'] = Variable<String>(startedByUserId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedByUserId.present) {
      map['completed_by_user_id'] = Variable<String>(completedByUserId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockCountsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('stockLocationId: $stockLocationId, ')
          ..write('operationId: $operationId, ')
          ..write('completionOperationId: $completionOperationId, ')
          ..write('countType: $countType, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('startedByUserId: $startedByUserId, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedByUserId: $completedByUserId, ')
          ..write('completedAt: $completedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class StockCountItems extends Table
    with TableInfo<StockCountItems, StockCountItemsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  StockCountItems(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> stockCountId = GeneratedColumn<String>(
    'stock_count_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_counts (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<int> expectedQuantityMilli = GeneratedColumn<int>(
    'expected_quantity_milli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> countedQuantityMilli = GeneratedColumn<int>(
    'counted_quantity_milli',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> varianceQuantityMilli = GeneratedColumn<int>(
    'variance_quantity_milli',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> countedByUserId = GeneratedColumn<String>(
    'counted_by_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> countedAt = GeneratedColumn<DateTime>(
    'counted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('version >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    stockCountId,
    productId,
    expectedQuantityMilli,
    countedQuantityMilli,
    varianceQuantityMilli,
    countedByUserId,
    countedAt,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_count_items';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {stockCountId, productId},
  ];
  @override
  StockCountItemsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockCountItemsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      stockCountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stock_count_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      expectedQuantityMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_quantity_milli'],
      )!,
      countedQuantityMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counted_quantity_milli'],
      ),
      varianceQuantityMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}variance_quantity_milli'],
      ),
      countedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counted_by_user_id'],
      ),
      countedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}counted_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  StockCountItems createAlias(String alias) {
    return StockCountItems(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (stock_count_id, organization_id) REFERENCES stock_counts (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) REFERENCES products (id, organization_id) ON DELETE RESTRICT',
  ];
}

class StockCountItemsData extends DataClass
    implements Insertable<StockCountItemsData> {
  final String id;
  final String organizationId;
  final String stockCountId;
  final String productId;
  final int expectedQuantityMilli;
  final int? countedQuantityMilli;
  final int? varianceQuantityMilli;
  final String? countedByUserId;
  final DateTime? countedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StockCountItemsData({
    required this.id,
    required this.organizationId,
    required this.stockCountId,
    required this.productId,
    required this.expectedQuantityMilli,
    this.countedQuantityMilli,
    this.varianceQuantityMilli,
    this.countedByUserId,
    this.countedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['stock_count_id'] = Variable<String>(stockCountId);
    map['product_id'] = Variable<String>(productId);
    map['expected_quantity_milli'] = Variable<int>(expectedQuantityMilli);
    if (!nullToAbsent || countedQuantityMilli != null) {
      map['counted_quantity_milli'] = Variable<int>(countedQuantityMilli);
    }
    if (!nullToAbsent || varianceQuantityMilli != null) {
      map['variance_quantity_milli'] = Variable<int>(varianceQuantityMilli);
    }
    if (!nullToAbsent || countedByUserId != null) {
      map['counted_by_user_id'] = Variable<String>(countedByUserId);
    }
    if (!nullToAbsent || countedAt != null) {
      map['counted_at'] = Variable<DateTime>(countedAt);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StockCountItemsCompanion toCompanion(bool nullToAbsent) {
    return StockCountItemsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      stockCountId: Value(stockCountId),
      productId: Value(productId),
      expectedQuantityMilli: Value(expectedQuantityMilli),
      countedQuantityMilli: countedQuantityMilli == null && nullToAbsent
          ? const Value.absent()
          : Value(countedQuantityMilli),
      varianceQuantityMilli: varianceQuantityMilli == null && nullToAbsent
          ? const Value.absent()
          : Value(varianceQuantityMilli),
      countedByUserId: countedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(countedByUserId),
      countedAt: countedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(countedAt),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StockCountItemsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockCountItemsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      stockCountId: serializer.fromJson<String>(json['stockCountId']),
      productId: serializer.fromJson<String>(json['productId']),
      expectedQuantityMilli: serializer.fromJson<int>(
        json['expectedQuantityMilli'],
      ),
      countedQuantityMilli: serializer.fromJson<int?>(
        json['countedQuantityMilli'],
      ),
      varianceQuantityMilli: serializer.fromJson<int?>(
        json['varianceQuantityMilli'],
      ),
      countedByUserId: serializer.fromJson<String?>(json['countedByUserId']),
      countedAt: serializer.fromJson<DateTime?>(json['countedAt']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'stockCountId': serializer.toJson<String>(stockCountId),
      'productId': serializer.toJson<String>(productId),
      'expectedQuantityMilli': serializer.toJson<int>(expectedQuantityMilli),
      'countedQuantityMilli': serializer.toJson<int?>(countedQuantityMilli),
      'varianceQuantityMilli': serializer.toJson<int?>(varianceQuantityMilli),
      'countedByUserId': serializer.toJson<String?>(countedByUserId),
      'countedAt': serializer.toJson<DateTime?>(countedAt),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StockCountItemsData copyWith({
    String? id,
    String? organizationId,
    String? stockCountId,
    String? productId,
    int? expectedQuantityMilli,
    Value<int?> countedQuantityMilli = const Value.absent(),
    Value<int?> varianceQuantityMilli = const Value.absent(),
    Value<String?> countedByUserId = const Value.absent(),
    Value<DateTime?> countedAt = const Value.absent(),
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StockCountItemsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    stockCountId: stockCountId ?? this.stockCountId,
    productId: productId ?? this.productId,
    expectedQuantityMilli: expectedQuantityMilli ?? this.expectedQuantityMilli,
    countedQuantityMilli: countedQuantityMilli.present
        ? countedQuantityMilli.value
        : this.countedQuantityMilli,
    varianceQuantityMilli: varianceQuantityMilli.present
        ? varianceQuantityMilli.value
        : this.varianceQuantityMilli,
    countedByUserId: countedByUserId.present
        ? countedByUserId.value
        : this.countedByUserId,
    countedAt: countedAt.present ? countedAt.value : this.countedAt,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StockCountItemsData copyWithCompanion(StockCountItemsCompanion data) {
    return StockCountItemsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      stockCountId: data.stockCountId.present
          ? data.stockCountId.value
          : this.stockCountId,
      productId: data.productId.present ? data.productId.value : this.productId,
      expectedQuantityMilli: data.expectedQuantityMilli.present
          ? data.expectedQuantityMilli.value
          : this.expectedQuantityMilli,
      countedQuantityMilli: data.countedQuantityMilli.present
          ? data.countedQuantityMilli.value
          : this.countedQuantityMilli,
      varianceQuantityMilli: data.varianceQuantityMilli.present
          ? data.varianceQuantityMilli.value
          : this.varianceQuantityMilli,
      countedByUserId: data.countedByUserId.present
          ? data.countedByUserId.value
          : this.countedByUserId,
      countedAt: data.countedAt.present ? data.countedAt.value : this.countedAt,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockCountItemsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('stockCountId: $stockCountId, ')
          ..write('productId: $productId, ')
          ..write('expectedQuantityMilli: $expectedQuantityMilli, ')
          ..write('countedQuantityMilli: $countedQuantityMilli, ')
          ..write('varianceQuantityMilli: $varianceQuantityMilli, ')
          ..write('countedByUserId: $countedByUserId, ')
          ..write('countedAt: $countedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    stockCountId,
    productId,
    expectedQuantityMilli,
    countedQuantityMilli,
    varianceQuantityMilli,
    countedByUserId,
    countedAt,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockCountItemsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.stockCountId == this.stockCountId &&
          other.productId == this.productId &&
          other.expectedQuantityMilli == this.expectedQuantityMilli &&
          other.countedQuantityMilli == this.countedQuantityMilli &&
          other.varianceQuantityMilli == this.varianceQuantityMilli &&
          other.countedByUserId == this.countedByUserId &&
          other.countedAt == this.countedAt &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StockCountItemsCompanion extends UpdateCompanion<StockCountItemsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> stockCountId;
  final Value<String> productId;
  final Value<int> expectedQuantityMilli;
  final Value<int?> countedQuantityMilli;
  final Value<int?> varianceQuantityMilli;
  final Value<String?> countedByUserId;
  final Value<DateTime?> countedAt;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StockCountItemsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.stockCountId = const Value.absent(),
    this.productId = const Value.absent(),
    this.expectedQuantityMilli = const Value.absent(),
    this.countedQuantityMilli = const Value.absent(),
    this.varianceQuantityMilli = const Value.absent(),
    this.countedByUserId = const Value.absent(),
    this.countedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockCountItemsCompanion.insert({
    required String id,
    required String organizationId,
    required String stockCountId,
    required String productId,
    required int expectedQuantityMilli,
    this.countedQuantityMilli = const Value.absent(),
    this.varianceQuantityMilli = const Value.absent(),
    this.countedByUserId = const Value.absent(),
    this.countedAt = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       stockCountId = Value(stockCountId),
       productId = Value(productId),
       expectedQuantityMilli = Value(expectedQuantityMilli),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StockCountItemsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? stockCountId,
    Expression<String>? productId,
    Expression<int>? expectedQuantityMilli,
    Expression<int>? countedQuantityMilli,
    Expression<int>? varianceQuantityMilli,
    Expression<String>? countedByUserId,
    Expression<DateTime>? countedAt,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (stockCountId != null) 'stock_count_id': stockCountId,
      if (productId != null) 'product_id': productId,
      if (expectedQuantityMilli != null)
        'expected_quantity_milli': expectedQuantityMilli,
      if (countedQuantityMilli != null)
        'counted_quantity_milli': countedQuantityMilli,
      if (varianceQuantityMilli != null)
        'variance_quantity_milli': varianceQuantityMilli,
      if (countedByUserId != null) 'counted_by_user_id': countedByUserId,
      if (countedAt != null) 'counted_at': countedAt,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockCountItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? stockCountId,
    Value<String>? productId,
    Value<int>? expectedQuantityMilli,
    Value<int?>? countedQuantityMilli,
    Value<int?>? varianceQuantityMilli,
    Value<String?>? countedByUserId,
    Value<DateTime?>? countedAt,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StockCountItemsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      stockCountId: stockCountId ?? this.stockCountId,
      productId: productId ?? this.productId,
      expectedQuantityMilli:
          expectedQuantityMilli ?? this.expectedQuantityMilli,
      countedQuantityMilli: countedQuantityMilli ?? this.countedQuantityMilli,
      varianceQuantityMilli:
          varianceQuantityMilli ?? this.varianceQuantityMilli,
      countedByUserId: countedByUserId ?? this.countedByUserId,
      countedAt: countedAt ?? this.countedAt,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (stockCountId.present) {
      map['stock_count_id'] = Variable<String>(stockCountId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (expectedQuantityMilli.present) {
      map['expected_quantity_milli'] = Variable<int>(
        expectedQuantityMilli.value,
      );
    }
    if (countedQuantityMilli.present) {
      map['counted_quantity_milli'] = Variable<int>(countedQuantityMilli.value);
    }
    if (varianceQuantityMilli.present) {
      map['variance_quantity_milli'] = Variable<int>(
        varianceQuantityMilli.value,
      );
    }
    if (countedByUserId.present) {
      map['counted_by_user_id'] = Variable<String>(countedByUserId.value);
    }
    if (countedAt.present) {
      map['counted_at'] = Variable<DateTime>(countedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockCountItemsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('stockCountId: $stockCountId, ')
          ..write('productId: $productId, ')
          ..write('expectedQuantityMilli: $expectedQuantityMilli, ')
          ..write('countedQuantityMilli: $countedQuantityMilli, ')
          ..write('varianceQuantityMilli: $varianceQuantityMilli, ')
          ..write('countedByUserId: $countedByUserId, ')
          ..write('countedAt: $countedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Registers extends Table with TableInfo<Registers, RegistersData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Registers(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> assignedDeviceId = GeneratedColumn<String>(
    'assigned_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> assignedByUserId = GeneratedColumn<String>(
    'assigned_by_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> assignedAt = GeneratedColumn<DateTime>(
    'assigned_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('1'),
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('version >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    code,
    name,
    assignedDeviceId,
    assignedByUserId,
    assignedAt,
    isActive,
    version,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'registers';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, branchId, code},
    {organizationId, branchId, assignedDeviceId},
    {id, organizationId, branchId},
  ];
  @override
  RegistersData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegistersData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      assignedDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assigned_device_id'],
      ),
      assignedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assigned_by_user_id'],
      ),
      assignedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}assigned_at'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  Registers createAlias(String alias) {
    return Registers(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
  ];
}

class RegistersData extends DataClass implements Insertable<RegistersData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String code;
  final String name;
  final String? assignedDeviceId;
  final String? assignedByUserId;
  final DateTime? assignedAt;
  final bool isActive;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const RegistersData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.code,
    required this.name,
    this.assignedDeviceId,
    this.assignedByUserId,
    this.assignedAt,
    required this.isActive,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || assignedDeviceId != null) {
      map['assigned_device_id'] = Variable<String>(assignedDeviceId);
    }
    if (!nullToAbsent || assignedByUserId != null) {
      map['assigned_by_user_id'] = Variable<String>(assignedByUserId);
    }
    if (!nullToAbsent || assignedAt != null) {
      map['assigned_at'] = Variable<DateTime>(assignedAt);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  RegistersCompanion toCompanion(bool nullToAbsent) {
    return RegistersCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      code: Value(code),
      name: Value(name),
      assignedDeviceId: assignedDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedDeviceId),
      assignedByUserId: assignedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedByUserId),
      assignedAt: assignedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedAt),
      isActive: Value(isActive),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory RegistersData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RegistersData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      assignedDeviceId: serializer.fromJson<String?>(json['assignedDeviceId']),
      assignedByUserId: serializer.fromJson<String?>(json['assignedByUserId']),
      assignedAt: serializer.fromJson<DateTime?>(json['assignedAt']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'assignedDeviceId': serializer.toJson<String?>(assignedDeviceId),
      'assignedByUserId': serializer.toJson<String?>(assignedByUserId),
      'assignedAt': serializer.toJson<DateTime?>(assignedAt),
      'isActive': serializer.toJson<bool>(isActive),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  RegistersData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? code,
    String? name,
    Value<String?> assignedDeviceId = const Value.absent(),
    Value<String?> assignedByUserId = const Value.absent(),
    Value<DateTime?> assignedAt = const Value.absent(),
    bool? isActive,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => RegistersData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    code: code ?? this.code,
    name: name ?? this.name,
    assignedDeviceId: assignedDeviceId.present
        ? assignedDeviceId.value
        : this.assignedDeviceId,
    assignedByUserId: assignedByUserId.present
        ? assignedByUserId.value
        : this.assignedByUserId,
    assignedAt: assignedAt.present ? assignedAt.value : this.assignedAt,
    isActive: isActive ?? this.isActive,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  RegistersData copyWithCompanion(RegistersCompanion data) {
    return RegistersData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      assignedDeviceId: data.assignedDeviceId.present
          ? data.assignedDeviceId.value
          : this.assignedDeviceId,
      assignedByUserId: data.assignedByUserId.present
          ? data.assignedByUserId.value
          : this.assignedByUserId,
      assignedAt: data.assignedAt.present
          ? data.assignedAt.value
          : this.assignedAt,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RegistersData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('assignedDeviceId: $assignedDeviceId, ')
          ..write('assignedByUserId: $assignedByUserId, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('isActive: $isActive, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    code,
    name,
    assignedDeviceId,
    assignedByUserId,
    assignedAt,
    isActive,
    version,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegistersData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.code == this.code &&
          other.name == this.name &&
          other.assignedDeviceId == this.assignedDeviceId &&
          other.assignedByUserId == this.assignedByUserId &&
          other.assignedAt == this.assignedAt &&
          other.isActive == this.isActive &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class RegistersCompanion extends UpdateCompanion<RegistersData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> code;
  final Value<String> name;
  final Value<String?> assignedDeviceId;
  final Value<String?> assignedByUserId;
  final Value<DateTime?> assignedAt;
  final Value<bool> isActive;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const RegistersCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.assignedDeviceId = const Value.absent(),
    this.assignedByUserId = const Value.absent(),
    this.assignedAt = const Value.absent(),
    this.isActive = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RegistersCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String code,
    required String name,
    this.assignedDeviceId = const Value.absent(),
    this.assignedByUserId = const Value.absent(),
    this.assignedAt = const Value.absent(),
    this.isActive = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       code = Value(code),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RegistersData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? assignedDeviceId,
    Expression<String>? assignedByUserId,
    Expression<DateTime>? assignedAt,
    Expression<bool>? isActive,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (assignedDeviceId != null) 'assigned_device_id': assignedDeviceId,
      if (assignedByUserId != null) 'assigned_by_user_id': assignedByUserId,
      if (assignedAt != null) 'assigned_at': assignedAt,
      if (isActive != null) 'is_active': isActive,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RegistersCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? code,
    Value<String>? name,
    Value<String?>? assignedDeviceId,
    Value<String?>? assignedByUserId,
    Value<DateTime?>? assignedAt,
    Value<bool>? isActive,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return RegistersCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      code: code ?? this.code,
      name: name ?? this.name,
      assignedDeviceId: assignedDeviceId ?? this.assignedDeviceId,
      assignedByUserId: assignedByUserId ?? this.assignedByUserId,
      assignedAt: assignedAt ?? this.assignedAt,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (assignedDeviceId.present) {
      map['assigned_device_id'] = Variable<String>(assignedDeviceId.value);
    }
    if (assignedByUserId.present) {
      map['assigned_by_user_id'] = Variable<String>(assignedByUserId.value);
    }
    if (assignedAt.present) {
      map['assigned_at'] = Variable<DateTime>(assignedAt.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RegistersCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('assignedDeviceId: $assignedDeviceId, ')
          ..write('assignedByUserId: $assignedByUserId, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('isActive: $isActive, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Shifts extends Table with TableInfo<Shifts, ShiftsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Shifts(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> registerId = GeneratedColumn<String>(
    'register_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES registers (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> closeOperationId = GeneratedColumn<String>(
    'close_operation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'open\''),
  );
  late final GeneratedColumn<int> openingCashMinor = GeneratedColumn<int>(
    'opening_cash_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('opening_cash_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> expectedCashMinor = GeneratedColumn<int>(
    'expected_cash_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> countedCashMinor = GeneratedColumn<int>(
    'counted_cash_minor',
    aliasedName,
    true,
    check: () => const i2.CustomExpression<bool>(
      'counted_cash_minor IS NULL OR counted_cash_minor >= 0',
    ),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> discrepancyMinor = GeneratedColumn<int>(
    'discrepancy_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> openingNotes = GeneratedColumn<String>(
    'opening_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> closingNotes = GeneratedColumn<String>(
    'closing_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> openedByUserId = GeneratedColumn<String>(
    'opened_by_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> closedByUserId = GeneratedColumn<String>(
    'closed_by_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> approvedByUserId = GeneratedColumn<String>(
    'approved_by_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> approvedAt = GeneratedColumn<DateTime>(
    'approved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> approvalNotes = GeneratedColumn<String>(
    'approval_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('version >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    registerId,
    deviceId,
    operationId,
    closeOperationId,
    status,
    openingCashMinor,
    expectedCashMinor,
    countedCashMinor,
    discrepancyMinor,
    openingNotes,
    closingNotes,
    openedByUserId,
    openedAt,
    closedByUserId,
    closedAt,
    approvedByUserId,
    approvedAt,
    approvalNotes,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shifts';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, operationId},
    {organizationId, closeOperationId},
    {id, organizationId, branchId},
  ];
  @override
  ShiftsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShiftsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      registerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}register_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      closeOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}close_operation_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      openingCashMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_cash_minor'],
      )!,
      expectedCashMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_cash_minor'],
      ),
      countedCashMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counted_cash_minor'],
      ),
      discrepancyMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discrepancy_minor'],
      ),
      openingNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opening_notes'],
      ),
      closingNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closing_notes'],
      ),
      openedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opened_by_user_id'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_at'],
      )!,
      closedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closed_by_user_id'],
      ),
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}closed_at'],
      ),
      approvedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approved_by_user_id'],
      ),
      approvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}approved_at'],
      ),
      approvalNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approval_notes'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  Shifts createAlias(String alias) {
    return Shifts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (register_id, organization_id, branch_id) REFERENCES registers (id, organization_id, branch_id) ON DELETE RESTRICT',
    'CHECK (status IN (\'open\', \'closed\'))',
    'CHECK ((status = \'open\' AND closed_at IS NULL AND closed_by_user_id IS NULL) OR (status = \'closed\' AND closed_at IS NOT NULL AND closed_by_user_id IS NOT NULL))',
  ];
}

class ShiftsData extends DataClass implements Insertable<ShiftsData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String registerId;
  final String deviceId;
  final String operationId;
  final String? closeOperationId;
  final String status;
  final int openingCashMinor;
  final int? expectedCashMinor;
  final int? countedCashMinor;
  final int? discrepancyMinor;
  final String? openingNotes;
  final String? closingNotes;
  final String openedByUserId;
  final DateTime openedAt;
  final String? closedByUserId;
  final DateTime? closedAt;
  final String? approvedByUserId;
  final DateTime? approvedAt;
  final String? approvalNotes;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ShiftsData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.registerId,
    required this.deviceId,
    required this.operationId,
    this.closeOperationId,
    required this.status,
    required this.openingCashMinor,
    this.expectedCashMinor,
    this.countedCashMinor,
    this.discrepancyMinor,
    this.openingNotes,
    this.closingNotes,
    required this.openedByUserId,
    required this.openedAt,
    this.closedByUserId,
    this.closedAt,
    this.approvedByUserId,
    this.approvedAt,
    this.approvalNotes,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['register_id'] = Variable<String>(registerId);
    map['device_id'] = Variable<String>(deviceId);
    map['operation_id'] = Variable<String>(operationId);
    if (!nullToAbsent || closeOperationId != null) {
      map['close_operation_id'] = Variable<String>(closeOperationId);
    }
    map['status'] = Variable<String>(status);
    map['opening_cash_minor'] = Variable<int>(openingCashMinor);
    if (!nullToAbsent || expectedCashMinor != null) {
      map['expected_cash_minor'] = Variable<int>(expectedCashMinor);
    }
    if (!nullToAbsent || countedCashMinor != null) {
      map['counted_cash_minor'] = Variable<int>(countedCashMinor);
    }
    if (!nullToAbsent || discrepancyMinor != null) {
      map['discrepancy_minor'] = Variable<int>(discrepancyMinor);
    }
    if (!nullToAbsent || openingNotes != null) {
      map['opening_notes'] = Variable<String>(openingNotes);
    }
    if (!nullToAbsent || closingNotes != null) {
      map['closing_notes'] = Variable<String>(closingNotes);
    }
    map['opened_by_user_id'] = Variable<String>(openedByUserId);
    map['opened_at'] = Variable<DateTime>(openedAt);
    if (!nullToAbsent || closedByUserId != null) {
      map['closed_by_user_id'] = Variable<String>(closedByUserId);
    }
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    if (!nullToAbsent || approvedByUserId != null) {
      map['approved_by_user_id'] = Variable<String>(approvedByUserId);
    }
    if (!nullToAbsent || approvedAt != null) {
      map['approved_at'] = Variable<DateTime>(approvedAt);
    }
    if (!nullToAbsent || approvalNotes != null) {
      map['approval_notes'] = Variable<String>(approvalNotes);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ShiftsCompanion toCompanion(bool nullToAbsent) {
    return ShiftsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      registerId: Value(registerId),
      deviceId: Value(deviceId),
      operationId: Value(operationId),
      closeOperationId: closeOperationId == null && nullToAbsent
          ? const Value.absent()
          : Value(closeOperationId),
      status: Value(status),
      openingCashMinor: Value(openingCashMinor),
      expectedCashMinor: expectedCashMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedCashMinor),
      countedCashMinor: countedCashMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(countedCashMinor),
      discrepancyMinor: discrepancyMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(discrepancyMinor),
      openingNotes: openingNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(openingNotes),
      closingNotes: closingNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(closingNotes),
      openedByUserId: Value(openedByUserId),
      openedAt: Value(openedAt),
      closedByUserId: closedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(closedByUserId),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      approvedByUserId: approvedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedByUserId),
      approvedAt: approvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedAt),
      approvalNotes: approvalNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(approvalNotes),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ShiftsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShiftsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      registerId: serializer.fromJson<String>(json['registerId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      closeOperationId: serializer.fromJson<String?>(json['closeOperationId']),
      status: serializer.fromJson<String>(json['status']),
      openingCashMinor: serializer.fromJson<int>(json['openingCashMinor']),
      expectedCashMinor: serializer.fromJson<int?>(json['expectedCashMinor']),
      countedCashMinor: serializer.fromJson<int?>(json['countedCashMinor']),
      discrepancyMinor: serializer.fromJson<int?>(json['discrepancyMinor']),
      openingNotes: serializer.fromJson<String?>(json['openingNotes']),
      closingNotes: serializer.fromJson<String?>(json['closingNotes']),
      openedByUserId: serializer.fromJson<String>(json['openedByUserId']),
      openedAt: serializer.fromJson<DateTime>(json['openedAt']),
      closedByUserId: serializer.fromJson<String?>(json['closedByUserId']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      approvedByUserId: serializer.fromJson<String?>(json['approvedByUserId']),
      approvedAt: serializer.fromJson<DateTime?>(json['approvedAt']),
      approvalNotes: serializer.fromJson<String?>(json['approvalNotes']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'registerId': serializer.toJson<String>(registerId),
      'deviceId': serializer.toJson<String>(deviceId),
      'operationId': serializer.toJson<String>(operationId),
      'closeOperationId': serializer.toJson<String?>(closeOperationId),
      'status': serializer.toJson<String>(status),
      'openingCashMinor': serializer.toJson<int>(openingCashMinor),
      'expectedCashMinor': serializer.toJson<int?>(expectedCashMinor),
      'countedCashMinor': serializer.toJson<int?>(countedCashMinor),
      'discrepancyMinor': serializer.toJson<int?>(discrepancyMinor),
      'openingNotes': serializer.toJson<String?>(openingNotes),
      'closingNotes': serializer.toJson<String?>(closingNotes),
      'openedByUserId': serializer.toJson<String>(openedByUserId),
      'openedAt': serializer.toJson<DateTime>(openedAt),
      'closedByUserId': serializer.toJson<String?>(closedByUserId),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'approvedByUserId': serializer.toJson<String?>(approvedByUserId),
      'approvedAt': serializer.toJson<DateTime?>(approvedAt),
      'approvalNotes': serializer.toJson<String?>(approvalNotes),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ShiftsData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? registerId,
    String? deviceId,
    String? operationId,
    Value<String?> closeOperationId = const Value.absent(),
    String? status,
    int? openingCashMinor,
    Value<int?> expectedCashMinor = const Value.absent(),
    Value<int?> countedCashMinor = const Value.absent(),
    Value<int?> discrepancyMinor = const Value.absent(),
    Value<String?> openingNotes = const Value.absent(),
    Value<String?> closingNotes = const Value.absent(),
    String? openedByUserId,
    DateTime? openedAt,
    Value<String?> closedByUserId = const Value.absent(),
    Value<DateTime?> closedAt = const Value.absent(),
    Value<String?> approvedByUserId = const Value.absent(),
    Value<DateTime?> approvedAt = const Value.absent(),
    Value<String?> approvalNotes = const Value.absent(),
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ShiftsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    registerId: registerId ?? this.registerId,
    deviceId: deviceId ?? this.deviceId,
    operationId: operationId ?? this.operationId,
    closeOperationId: closeOperationId.present
        ? closeOperationId.value
        : this.closeOperationId,
    status: status ?? this.status,
    openingCashMinor: openingCashMinor ?? this.openingCashMinor,
    expectedCashMinor: expectedCashMinor.present
        ? expectedCashMinor.value
        : this.expectedCashMinor,
    countedCashMinor: countedCashMinor.present
        ? countedCashMinor.value
        : this.countedCashMinor,
    discrepancyMinor: discrepancyMinor.present
        ? discrepancyMinor.value
        : this.discrepancyMinor,
    openingNotes: openingNotes.present ? openingNotes.value : this.openingNotes,
    closingNotes: closingNotes.present ? closingNotes.value : this.closingNotes,
    openedByUserId: openedByUserId ?? this.openedByUserId,
    openedAt: openedAt ?? this.openedAt,
    closedByUserId: closedByUserId.present
        ? closedByUserId.value
        : this.closedByUserId,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    approvedByUserId: approvedByUserId.present
        ? approvedByUserId.value
        : this.approvedByUserId,
    approvedAt: approvedAt.present ? approvedAt.value : this.approvedAt,
    approvalNotes: approvalNotes.present
        ? approvalNotes.value
        : this.approvalNotes,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ShiftsData copyWithCompanion(ShiftsCompanion data) {
    return ShiftsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      registerId: data.registerId.present
          ? data.registerId.value
          : this.registerId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      closeOperationId: data.closeOperationId.present
          ? data.closeOperationId.value
          : this.closeOperationId,
      status: data.status.present ? data.status.value : this.status,
      openingCashMinor: data.openingCashMinor.present
          ? data.openingCashMinor.value
          : this.openingCashMinor,
      expectedCashMinor: data.expectedCashMinor.present
          ? data.expectedCashMinor.value
          : this.expectedCashMinor,
      countedCashMinor: data.countedCashMinor.present
          ? data.countedCashMinor.value
          : this.countedCashMinor,
      discrepancyMinor: data.discrepancyMinor.present
          ? data.discrepancyMinor.value
          : this.discrepancyMinor,
      openingNotes: data.openingNotes.present
          ? data.openingNotes.value
          : this.openingNotes,
      closingNotes: data.closingNotes.present
          ? data.closingNotes.value
          : this.closingNotes,
      openedByUserId: data.openedByUserId.present
          ? data.openedByUserId.value
          : this.openedByUserId,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      closedByUserId: data.closedByUserId.present
          ? data.closedByUserId.value
          : this.closedByUserId,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      approvedByUserId: data.approvedByUserId.present
          ? data.approvedByUserId.value
          : this.approvedByUserId,
      approvedAt: data.approvedAt.present
          ? data.approvedAt.value
          : this.approvedAt,
      approvalNotes: data.approvalNotes.present
          ? data.approvalNotes.value
          : this.approvalNotes,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShiftsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('registerId: $registerId, ')
          ..write('deviceId: $deviceId, ')
          ..write('operationId: $operationId, ')
          ..write('closeOperationId: $closeOperationId, ')
          ..write('status: $status, ')
          ..write('openingCashMinor: $openingCashMinor, ')
          ..write('expectedCashMinor: $expectedCashMinor, ')
          ..write('countedCashMinor: $countedCashMinor, ')
          ..write('discrepancyMinor: $discrepancyMinor, ')
          ..write('openingNotes: $openingNotes, ')
          ..write('closingNotes: $closingNotes, ')
          ..write('openedByUserId: $openedByUserId, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedByUserId: $closedByUserId, ')
          ..write('closedAt: $closedAt, ')
          ..write('approvedByUserId: $approvedByUserId, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('approvalNotes: $approvalNotes, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    organizationId,
    branchId,
    registerId,
    deviceId,
    operationId,
    closeOperationId,
    status,
    openingCashMinor,
    expectedCashMinor,
    countedCashMinor,
    discrepancyMinor,
    openingNotes,
    closingNotes,
    openedByUserId,
    openedAt,
    closedByUserId,
    closedAt,
    approvedByUserId,
    approvedAt,
    approvalNotes,
    version,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.registerId == this.registerId &&
          other.deviceId == this.deviceId &&
          other.operationId == this.operationId &&
          other.closeOperationId == this.closeOperationId &&
          other.status == this.status &&
          other.openingCashMinor == this.openingCashMinor &&
          other.expectedCashMinor == this.expectedCashMinor &&
          other.countedCashMinor == this.countedCashMinor &&
          other.discrepancyMinor == this.discrepancyMinor &&
          other.openingNotes == this.openingNotes &&
          other.closingNotes == this.closingNotes &&
          other.openedByUserId == this.openedByUserId &&
          other.openedAt == this.openedAt &&
          other.closedByUserId == this.closedByUserId &&
          other.closedAt == this.closedAt &&
          other.approvedByUserId == this.approvedByUserId &&
          other.approvedAt == this.approvedAt &&
          other.approvalNotes == this.approvalNotes &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ShiftsCompanion extends UpdateCompanion<ShiftsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> registerId;
  final Value<String> deviceId;
  final Value<String> operationId;
  final Value<String?> closeOperationId;
  final Value<String> status;
  final Value<int> openingCashMinor;
  final Value<int?> expectedCashMinor;
  final Value<int?> countedCashMinor;
  final Value<int?> discrepancyMinor;
  final Value<String?> openingNotes;
  final Value<String?> closingNotes;
  final Value<String> openedByUserId;
  final Value<DateTime> openedAt;
  final Value<String?> closedByUserId;
  final Value<DateTime?> closedAt;
  final Value<String?> approvedByUserId;
  final Value<DateTime?> approvedAt;
  final Value<String?> approvalNotes;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ShiftsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.registerId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.closeOperationId = const Value.absent(),
    this.status = const Value.absent(),
    this.openingCashMinor = const Value.absent(),
    this.expectedCashMinor = const Value.absent(),
    this.countedCashMinor = const Value.absent(),
    this.discrepancyMinor = const Value.absent(),
    this.openingNotes = const Value.absent(),
    this.closingNotes = const Value.absent(),
    this.openedByUserId = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.closedByUserId = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.approvedByUserId = const Value.absent(),
    this.approvedAt = const Value.absent(),
    this.approvalNotes = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShiftsCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String registerId,
    required String deviceId,
    required String operationId,
    this.closeOperationId = const Value.absent(),
    this.status = const Value.absent(),
    required int openingCashMinor,
    this.expectedCashMinor = const Value.absent(),
    this.countedCashMinor = const Value.absent(),
    this.discrepancyMinor = const Value.absent(),
    this.openingNotes = const Value.absent(),
    this.closingNotes = const Value.absent(),
    required String openedByUserId,
    required DateTime openedAt,
    this.closedByUserId = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.approvedByUserId = const Value.absent(),
    this.approvedAt = const Value.absent(),
    this.approvalNotes = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       registerId = Value(registerId),
       deviceId = Value(deviceId),
       operationId = Value(operationId),
       openingCashMinor = Value(openingCashMinor),
       openedByUserId = Value(openedByUserId),
       openedAt = Value(openedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ShiftsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? registerId,
    Expression<String>? deviceId,
    Expression<String>? operationId,
    Expression<String>? closeOperationId,
    Expression<String>? status,
    Expression<int>? openingCashMinor,
    Expression<int>? expectedCashMinor,
    Expression<int>? countedCashMinor,
    Expression<int>? discrepancyMinor,
    Expression<String>? openingNotes,
    Expression<String>? closingNotes,
    Expression<String>? openedByUserId,
    Expression<DateTime>? openedAt,
    Expression<String>? closedByUserId,
    Expression<DateTime>? closedAt,
    Expression<String>? approvedByUserId,
    Expression<DateTime>? approvedAt,
    Expression<String>? approvalNotes,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (registerId != null) 'register_id': registerId,
      if (deviceId != null) 'device_id': deviceId,
      if (operationId != null) 'operation_id': operationId,
      if (closeOperationId != null) 'close_operation_id': closeOperationId,
      if (status != null) 'status': status,
      if (openingCashMinor != null) 'opening_cash_minor': openingCashMinor,
      if (expectedCashMinor != null) 'expected_cash_minor': expectedCashMinor,
      if (countedCashMinor != null) 'counted_cash_minor': countedCashMinor,
      if (discrepancyMinor != null) 'discrepancy_minor': discrepancyMinor,
      if (openingNotes != null) 'opening_notes': openingNotes,
      if (closingNotes != null) 'closing_notes': closingNotes,
      if (openedByUserId != null) 'opened_by_user_id': openedByUserId,
      if (openedAt != null) 'opened_at': openedAt,
      if (closedByUserId != null) 'closed_by_user_id': closedByUserId,
      if (closedAt != null) 'closed_at': closedAt,
      if (approvedByUserId != null) 'approved_by_user_id': approvedByUserId,
      if (approvedAt != null) 'approved_at': approvedAt,
      if (approvalNotes != null) 'approval_notes': approvalNotes,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShiftsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? registerId,
    Value<String>? deviceId,
    Value<String>? operationId,
    Value<String?>? closeOperationId,
    Value<String>? status,
    Value<int>? openingCashMinor,
    Value<int?>? expectedCashMinor,
    Value<int?>? countedCashMinor,
    Value<int?>? discrepancyMinor,
    Value<String?>? openingNotes,
    Value<String?>? closingNotes,
    Value<String>? openedByUserId,
    Value<DateTime>? openedAt,
    Value<String?>? closedByUserId,
    Value<DateTime?>? closedAt,
    Value<String?>? approvedByUserId,
    Value<DateTime?>? approvedAt,
    Value<String?>? approvalNotes,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ShiftsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      registerId: registerId ?? this.registerId,
      deviceId: deviceId ?? this.deviceId,
      operationId: operationId ?? this.operationId,
      closeOperationId: closeOperationId ?? this.closeOperationId,
      status: status ?? this.status,
      openingCashMinor: openingCashMinor ?? this.openingCashMinor,
      expectedCashMinor: expectedCashMinor ?? this.expectedCashMinor,
      countedCashMinor: countedCashMinor ?? this.countedCashMinor,
      discrepancyMinor: discrepancyMinor ?? this.discrepancyMinor,
      openingNotes: openingNotes ?? this.openingNotes,
      closingNotes: closingNotes ?? this.closingNotes,
      openedByUserId: openedByUserId ?? this.openedByUserId,
      openedAt: openedAt ?? this.openedAt,
      closedByUserId: closedByUserId ?? this.closedByUserId,
      closedAt: closedAt ?? this.closedAt,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedAt: approvedAt ?? this.approvedAt,
      approvalNotes: approvalNotes ?? this.approvalNotes,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (registerId.present) {
      map['register_id'] = Variable<String>(registerId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (closeOperationId.present) {
      map['close_operation_id'] = Variable<String>(closeOperationId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (openingCashMinor.present) {
      map['opening_cash_minor'] = Variable<int>(openingCashMinor.value);
    }
    if (expectedCashMinor.present) {
      map['expected_cash_minor'] = Variable<int>(expectedCashMinor.value);
    }
    if (countedCashMinor.present) {
      map['counted_cash_minor'] = Variable<int>(countedCashMinor.value);
    }
    if (discrepancyMinor.present) {
      map['discrepancy_minor'] = Variable<int>(discrepancyMinor.value);
    }
    if (openingNotes.present) {
      map['opening_notes'] = Variable<String>(openingNotes.value);
    }
    if (closingNotes.present) {
      map['closing_notes'] = Variable<String>(closingNotes.value);
    }
    if (openedByUserId.present) {
      map['opened_by_user_id'] = Variable<String>(openedByUserId.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (closedByUserId.present) {
      map['closed_by_user_id'] = Variable<String>(closedByUserId.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (approvedByUserId.present) {
      map['approved_by_user_id'] = Variable<String>(approvedByUserId.value);
    }
    if (approvedAt.present) {
      map['approved_at'] = Variable<DateTime>(approvedAt.value);
    }
    if (approvalNotes.present) {
      map['approval_notes'] = Variable<String>(approvalNotes.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('registerId: $registerId, ')
          ..write('deviceId: $deviceId, ')
          ..write('operationId: $operationId, ')
          ..write('closeOperationId: $closeOperationId, ')
          ..write('status: $status, ')
          ..write('openingCashMinor: $openingCashMinor, ')
          ..write('expectedCashMinor: $expectedCashMinor, ')
          ..write('countedCashMinor: $countedCashMinor, ')
          ..write('discrepancyMinor: $discrepancyMinor, ')
          ..write('openingNotes: $openingNotes, ')
          ..write('closingNotes: $closingNotes, ')
          ..write('openedByUserId: $openedByUserId, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedByUserId: $closedByUserId, ')
          ..write('closedAt: $closedAt, ')
          ..write('approvedByUserId: $approvedByUserId, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('approvalNotes: $approvalNotes, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class CashMovements extends Table
    with TableInfo<CashMovements, CashMovementsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  CashMovements(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> registerId = GeneratedColumn<String>(
    'register_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES registers (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> shiftId = GeneratedColumn<String>(
    'shift_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shifts (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> movementType = GeneratedColumn<String>(
    'movement_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> createdByUserId = GeneratedColumn<String>(
    'created_by_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> approvedByUserId = GeneratedColumn<String>(
    'approved_by_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> approvedAt = GeneratedColumn<DateTime>(
    'approved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    registerId,
    shiftId,
    operationId,
    movementType,
    amountMinor,
    reason,
    createdByUserId,
    approvedByUserId,
    approvedAt,
    occurredAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cash_movements';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, operationId},
  ];
  @override
  CashMovementsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CashMovementsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      registerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}register_id'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      movementType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}movement_type'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      createdByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_user_id'],
      )!,
      approvedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approved_by_user_id'],
      ),
      approvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}approved_at'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  CashMovements createAlias(String alias) {
    return CashMovements(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (register_id, organization_id, branch_id) REFERENCES registers (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (shift_id, organization_id, branch_id) REFERENCES shifts (id, organization_id, branch_id) ON DELETE RESTRICT',
    'CHECK (movement_type IN (\'cash_in\', \'cash_out\', \'payout\', \'correction\'))',
    'CHECK ((movement_type = \'cash_in\' AND amount_minor > 0) OR (movement_type IN (\'cash_out\', \'payout\') AND amount_minor < 0) OR (movement_type = \'correction\' AND amount_minor <> 0))',
  ];
}

class CashMovementsData extends DataClass
    implements Insertable<CashMovementsData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String registerId;
  final String shiftId;
  final String operationId;
  final String movementType;
  final int amountMinor;
  final String reason;
  final String createdByUserId;
  final String? approvedByUserId;
  final DateTime? approvedAt;
  final DateTime occurredAt;
  final DateTime createdAt;
  const CashMovementsData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.registerId,
    required this.shiftId,
    required this.operationId,
    required this.movementType,
    required this.amountMinor,
    required this.reason,
    required this.createdByUserId,
    this.approvedByUserId,
    this.approvedAt,
    required this.occurredAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['register_id'] = Variable<String>(registerId);
    map['shift_id'] = Variable<String>(shiftId);
    map['operation_id'] = Variable<String>(operationId);
    map['movement_type'] = Variable<String>(movementType);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['reason'] = Variable<String>(reason);
    map['created_by_user_id'] = Variable<String>(createdByUserId);
    if (!nullToAbsent || approvedByUserId != null) {
      map['approved_by_user_id'] = Variable<String>(approvedByUserId);
    }
    if (!nullToAbsent || approvedAt != null) {
      map['approved_at'] = Variable<DateTime>(approvedAt);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CashMovementsCompanion toCompanion(bool nullToAbsent) {
    return CashMovementsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      registerId: Value(registerId),
      shiftId: Value(shiftId),
      operationId: Value(operationId),
      movementType: Value(movementType),
      amountMinor: Value(amountMinor),
      reason: Value(reason),
      createdByUserId: Value(createdByUserId),
      approvedByUserId: approvedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedByUserId),
      approvedAt: approvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedAt),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
    );
  }

  factory CashMovementsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CashMovementsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      registerId: serializer.fromJson<String>(json['registerId']),
      shiftId: serializer.fromJson<String>(json['shiftId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      movementType: serializer.fromJson<String>(json['movementType']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      reason: serializer.fromJson<String>(json['reason']),
      createdByUserId: serializer.fromJson<String>(json['createdByUserId']),
      approvedByUserId: serializer.fromJson<String?>(json['approvedByUserId']),
      approvedAt: serializer.fromJson<DateTime?>(json['approvedAt']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'registerId': serializer.toJson<String>(registerId),
      'shiftId': serializer.toJson<String>(shiftId),
      'operationId': serializer.toJson<String>(operationId),
      'movementType': serializer.toJson<String>(movementType),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'reason': serializer.toJson<String>(reason),
      'createdByUserId': serializer.toJson<String>(createdByUserId),
      'approvedByUserId': serializer.toJson<String?>(approvedByUserId),
      'approvedAt': serializer.toJson<DateTime?>(approvedAt),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CashMovementsData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? registerId,
    String? shiftId,
    String? operationId,
    String? movementType,
    int? amountMinor,
    String? reason,
    String? createdByUserId,
    Value<String?> approvedByUserId = const Value.absent(),
    Value<DateTime?> approvedAt = const Value.absent(),
    DateTime? occurredAt,
    DateTime? createdAt,
  }) => CashMovementsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    registerId: registerId ?? this.registerId,
    shiftId: shiftId ?? this.shiftId,
    operationId: operationId ?? this.operationId,
    movementType: movementType ?? this.movementType,
    amountMinor: amountMinor ?? this.amountMinor,
    reason: reason ?? this.reason,
    createdByUserId: createdByUserId ?? this.createdByUserId,
    approvedByUserId: approvedByUserId.present
        ? approvedByUserId.value
        : this.approvedByUserId,
    approvedAt: approvedAt.present ? approvedAt.value : this.approvedAt,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt ?? this.createdAt,
  );
  CashMovementsData copyWithCompanion(CashMovementsCompanion data) {
    return CashMovementsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      registerId: data.registerId.present
          ? data.registerId.value
          : this.registerId,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      movementType: data.movementType.present
          ? data.movementType.value
          : this.movementType,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
      approvedByUserId: data.approvedByUserId.present
          ? data.approvedByUserId.value
          : this.approvedByUserId,
      approvedAt: data.approvedAt.present
          ? data.approvedAt.value
          : this.approvedAt,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CashMovementsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('registerId: $registerId, ')
          ..write('shiftId: $shiftId, ')
          ..write('operationId: $operationId, ')
          ..write('movementType: $movementType, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('reason: $reason, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('approvedByUserId: $approvedByUserId, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    registerId,
    shiftId,
    operationId,
    movementType,
    amountMinor,
    reason,
    createdByUserId,
    approvedByUserId,
    approvedAt,
    occurredAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CashMovementsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.registerId == this.registerId &&
          other.shiftId == this.shiftId &&
          other.operationId == this.operationId &&
          other.movementType == this.movementType &&
          other.amountMinor == this.amountMinor &&
          other.reason == this.reason &&
          other.createdByUserId == this.createdByUserId &&
          other.approvedByUserId == this.approvedByUserId &&
          other.approvedAt == this.approvedAt &&
          other.occurredAt == this.occurredAt &&
          other.createdAt == this.createdAt);
}

class CashMovementsCompanion extends UpdateCompanion<CashMovementsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> registerId;
  final Value<String> shiftId;
  final Value<String> operationId;
  final Value<String> movementType;
  final Value<int> amountMinor;
  final Value<String> reason;
  final Value<String> createdByUserId;
  final Value<String?> approvedByUserId;
  final Value<DateTime?> approvedAt;
  final Value<DateTime> occurredAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CashMovementsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.registerId = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.movementType = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.approvedByUserId = const Value.absent(),
    this.approvedAt = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CashMovementsCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String registerId,
    required String shiftId,
    required String operationId,
    required String movementType,
    required int amountMinor,
    required String reason,
    required String createdByUserId,
    this.approvedByUserId = const Value.absent(),
    this.approvedAt = const Value.absent(),
    required DateTime occurredAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       registerId = Value(registerId),
       shiftId = Value(shiftId),
       operationId = Value(operationId),
       movementType = Value(movementType),
       amountMinor = Value(amountMinor),
       reason = Value(reason),
       createdByUserId = Value(createdByUserId),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt);
  static Insertable<CashMovementsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? registerId,
    Expression<String>? shiftId,
    Expression<String>? operationId,
    Expression<String>? movementType,
    Expression<int>? amountMinor,
    Expression<String>? reason,
    Expression<String>? createdByUserId,
    Expression<String>? approvedByUserId,
    Expression<DateTime>? approvedAt,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (registerId != null) 'register_id': registerId,
      if (shiftId != null) 'shift_id': shiftId,
      if (operationId != null) 'operation_id': operationId,
      if (movementType != null) 'movement_type': movementType,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (reason != null) 'reason': reason,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      if (approvedByUserId != null) 'approved_by_user_id': approvedByUserId,
      if (approvedAt != null) 'approved_at': approvedAt,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CashMovementsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? registerId,
    Value<String>? shiftId,
    Value<String>? operationId,
    Value<String>? movementType,
    Value<int>? amountMinor,
    Value<String>? reason,
    Value<String>? createdByUserId,
    Value<String?>? approvedByUserId,
    Value<DateTime?>? approvedAt,
    Value<DateTime>? occurredAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CashMovementsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      registerId: registerId ?? this.registerId,
      shiftId: shiftId ?? this.shiftId,
      operationId: operationId ?? this.operationId,
      movementType: movementType ?? this.movementType,
      amountMinor: amountMinor ?? this.amountMinor,
      reason: reason ?? this.reason,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedAt: approvedAt ?? this.approvedAt,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (registerId.present) {
      map['register_id'] = Variable<String>(registerId.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<String>(shiftId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (movementType.present) {
      map['movement_type'] = Variable<String>(movementType.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<String>(createdByUserId.value);
    }
    if (approvedByUserId.present) {
      map['approved_by_user_id'] = Variable<String>(approvedByUserId.value);
    }
    if (approvedAt.present) {
      map['approved_at'] = Variable<DateTime>(approvedAt.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CashMovementsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('registerId: $registerId, ')
          ..write('shiftId: $shiftId, ')
          ..write('operationId: $operationId, ')
          ..write('movementType: $movementType, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('reason: $reason, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('approvedByUserId: $approvedByUserId, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ShiftCounts extends Table with TableInfo<ShiftCounts, ShiftCountsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ShiftCounts(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> shiftId = GeneratedColumn<String>(
    'shift_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shifts (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> expectedAmountMinor = GeneratedColumn<int>(
    'expected_amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> countedAmountMinor = GeneratedColumn<int>(
    'counted_amount_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('counted_amount_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> discrepancyMinor = GeneratedColumn<int>(
    'discrepancy_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> countedByUserId = GeneratedColumn<String>(
    'counted_by_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> countedAt = GeneratedColumn<DateTime>(
    'counted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    shiftId,
    paymentMethod,
    expectedAmountMinor,
    countedAmountMinor,
    discrepancyMinor,
    countedByUserId,
    countedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shift_counts';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {shiftId, paymentMethod},
  ];
  @override
  ShiftCountsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShiftCountsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift_id'],
      )!,
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      expectedAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_amount_minor'],
      )!,
      countedAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counted_amount_minor'],
      )!,
      discrepancyMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discrepancy_minor'],
      )!,
      countedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counted_by_user_id'],
      )!,
      countedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}counted_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  ShiftCounts createAlias(String alias) {
    return ShiftCounts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (shift_id, organization_id, branch_id) REFERENCES shifts (id, organization_id, branch_id) ON DELETE RESTRICT',
    'CHECK (payment_method IN (\'cash\', \'card\', \'e_wallet\'))',
    'CHECK (discrepancy_minor = counted_amount_minor - expected_amount_minor)',
  ];
}

class ShiftCountsData extends DataClass implements Insertable<ShiftCountsData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String shiftId;
  final String paymentMethod;
  final int expectedAmountMinor;
  final int countedAmountMinor;
  final int discrepancyMinor;
  final String countedByUserId;
  final DateTime countedAt;
  final DateTime createdAt;
  const ShiftCountsData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.shiftId,
    required this.paymentMethod,
    required this.expectedAmountMinor,
    required this.countedAmountMinor,
    required this.discrepancyMinor,
    required this.countedByUserId,
    required this.countedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['shift_id'] = Variable<String>(shiftId);
    map['payment_method'] = Variable<String>(paymentMethod);
    map['expected_amount_minor'] = Variable<int>(expectedAmountMinor);
    map['counted_amount_minor'] = Variable<int>(countedAmountMinor);
    map['discrepancy_minor'] = Variable<int>(discrepancyMinor);
    map['counted_by_user_id'] = Variable<String>(countedByUserId);
    map['counted_at'] = Variable<DateTime>(countedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ShiftCountsCompanion toCompanion(bool nullToAbsent) {
    return ShiftCountsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      shiftId: Value(shiftId),
      paymentMethod: Value(paymentMethod),
      expectedAmountMinor: Value(expectedAmountMinor),
      countedAmountMinor: Value(countedAmountMinor),
      discrepancyMinor: Value(discrepancyMinor),
      countedByUserId: Value(countedByUserId),
      countedAt: Value(countedAt),
      createdAt: Value(createdAt),
    );
  }

  factory ShiftCountsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShiftCountsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      shiftId: serializer.fromJson<String>(json['shiftId']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      expectedAmountMinor: serializer.fromJson<int>(
        json['expectedAmountMinor'],
      ),
      countedAmountMinor: serializer.fromJson<int>(json['countedAmountMinor']),
      discrepancyMinor: serializer.fromJson<int>(json['discrepancyMinor']),
      countedByUserId: serializer.fromJson<String>(json['countedByUserId']),
      countedAt: serializer.fromJson<DateTime>(json['countedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'shiftId': serializer.toJson<String>(shiftId),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'expectedAmountMinor': serializer.toJson<int>(expectedAmountMinor),
      'countedAmountMinor': serializer.toJson<int>(countedAmountMinor),
      'discrepancyMinor': serializer.toJson<int>(discrepancyMinor),
      'countedByUserId': serializer.toJson<String>(countedByUserId),
      'countedAt': serializer.toJson<DateTime>(countedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ShiftCountsData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? shiftId,
    String? paymentMethod,
    int? expectedAmountMinor,
    int? countedAmountMinor,
    int? discrepancyMinor,
    String? countedByUserId,
    DateTime? countedAt,
    DateTime? createdAt,
  }) => ShiftCountsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    shiftId: shiftId ?? this.shiftId,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    expectedAmountMinor: expectedAmountMinor ?? this.expectedAmountMinor,
    countedAmountMinor: countedAmountMinor ?? this.countedAmountMinor,
    discrepancyMinor: discrepancyMinor ?? this.discrepancyMinor,
    countedByUserId: countedByUserId ?? this.countedByUserId,
    countedAt: countedAt ?? this.countedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ShiftCountsData copyWithCompanion(ShiftCountsCompanion data) {
    return ShiftCountsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      expectedAmountMinor: data.expectedAmountMinor.present
          ? data.expectedAmountMinor.value
          : this.expectedAmountMinor,
      countedAmountMinor: data.countedAmountMinor.present
          ? data.countedAmountMinor.value
          : this.countedAmountMinor,
      discrepancyMinor: data.discrepancyMinor.present
          ? data.discrepancyMinor.value
          : this.discrepancyMinor,
      countedByUserId: data.countedByUserId.present
          ? data.countedByUserId.value
          : this.countedByUserId,
      countedAt: data.countedAt.present ? data.countedAt.value : this.countedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShiftCountsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('shiftId: $shiftId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('expectedAmountMinor: $expectedAmountMinor, ')
          ..write('countedAmountMinor: $countedAmountMinor, ')
          ..write('discrepancyMinor: $discrepancyMinor, ')
          ..write('countedByUserId: $countedByUserId, ')
          ..write('countedAt: $countedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    shiftId,
    paymentMethod,
    expectedAmountMinor,
    countedAmountMinor,
    discrepancyMinor,
    countedByUserId,
    countedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftCountsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.shiftId == this.shiftId &&
          other.paymentMethod == this.paymentMethod &&
          other.expectedAmountMinor == this.expectedAmountMinor &&
          other.countedAmountMinor == this.countedAmountMinor &&
          other.discrepancyMinor == this.discrepancyMinor &&
          other.countedByUserId == this.countedByUserId &&
          other.countedAt == this.countedAt &&
          other.createdAt == this.createdAt);
}

class ShiftCountsCompanion extends UpdateCompanion<ShiftCountsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> shiftId;
  final Value<String> paymentMethod;
  final Value<int> expectedAmountMinor;
  final Value<int> countedAmountMinor;
  final Value<int> discrepancyMinor;
  final Value<String> countedByUserId;
  final Value<DateTime> countedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ShiftCountsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.expectedAmountMinor = const Value.absent(),
    this.countedAmountMinor = const Value.absent(),
    this.discrepancyMinor = const Value.absent(),
    this.countedByUserId = const Value.absent(),
    this.countedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShiftCountsCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String shiftId,
    required String paymentMethod,
    required int expectedAmountMinor,
    required int countedAmountMinor,
    required int discrepancyMinor,
    required String countedByUserId,
    required DateTime countedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       shiftId = Value(shiftId),
       paymentMethod = Value(paymentMethod),
       expectedAmountMinor = Value(expectedAmountMinor),
       countedAmountMinor = Value(countedAmountMinor),
       discrepancyMinor = Value(discrepancyMinor),
       countedByUserId = Value(countedByUserId),
       countedAt = Value(countedAt),
       createdAt = Value(createdAt);
  static Insertable<ShiftCountsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? shiftId,
    Expression<String>? paymentMethod,
    Expression<int>? expectedAmountMinor,
    Expression<int>? countedAmountMinor,
    Expression<int>? discrepancyMinor,
    Expression<String>? countedByUserId,
    Expression<DateTime>? countedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (shiftId != null) 'shift_id': shiftId,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (expectedAmountMinor != null)
        'expected_amount_minor': expectedAmountMinor,
      if (countedAmountMinor != null)
        'counted_amount_minor': countedAmountMinor,
      if (discrepancyMinor != null) 'discrepancy_minor': discrepancyMinor,
      if (countedByUserId != null) 'counted_by_user_id': countedByUserId,
      if (countedAt != null) 'counted_at': countedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShiftCountsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? shiftId,
    Value<String>? paymentMethod,
    Value<int>? expectedAmountMinor,
    Value<int>? countedAmountMinor,
    Value<int>? discrepancyMinor,
    Value<String>? countedByUserId,
    Value<DateTime>? countedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ShiftCountsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      shiftId: shiftId ?? this.shiftId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      expectedAmountMinor: expectedAmountMinor ?? this.expectedAmountMinor,
      countedAmountMinor: countedAmountMinor ?? this.countedAmountMinor,
      discrepancyMinor: discrepancyMinor ?? this.discrepancyMinor,
      countedByUserId: countedByUserId ?? this.countedByUserId,
      countedAt: countedAt ?? this.countedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<String>(shiftId.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (expectedAmountMinor.present) {
      map['expected_amount_minor'] = Variable<int>(expectedAmountMinor.value);
    }
    if (countedAmountMinor.present) {
      map['counted_amount_minor'] = Variable<int>(countedAmountMinor.value);
    }
    if (discrepancyMinor.present) {
      map['discrepancy_minor'] = Variable<int>(discrepancyMinor.value);
    }
    if (countedByUserId.present) {
      map['counted_by_user_id'] = Variable<String>(countedByUserId.value);
    }
    if (countedAt.present) {
      map['counted_at'] = Variable<DateTime>(countedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftCountsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('shiftId: $shiftId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('expectedAmountMinor: $expectedAmountMinor, ')
          ..write('countedAmountMinor: $countedAmountMinor, ')
          ..write('discrepancyMinor: $discrepancyMinor, ')
          ..write('countedByUserId: $countedByUserId, ')
          ..write('countedAt: $countedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Sales extends Table with TableInfo<Sales, SalesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Sales(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> registerId = GeneratedColumn<String>(
    'register_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES registers (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> shiftId = GeneratedColumn<String>(
    'shift_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shifts (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> inventoryTransactionId =
      GeneratedColumn<String>(
        'inventory_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES inventory_transactions (id) ON DELETE RESTRICT',
        ),
      );
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> receiptNumber = GeneratedColumn<String>(
    'receipt_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'draft\''),
  );
  late final GeneratedColumn<String> cashierUserId = GeneratedColumn<String>(
    'cashier_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> subtotalMinor = GeneratedColumn<int>(
    'subtotal_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('subtotal_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<int> discountMinor = GeneratedColumn<int>(
    'discount_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('discount_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<int> taxMinor = GeneratedColumn<int>(
    'tax_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('tax_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<int> totalMinor = GeneratedColumn<int>(
    'total_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('total_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<int> tenderedMinor = GeneratedColumn<int>(
    'tendered_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('tendered_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<int> changeMinor = GeneratedColumn<int>(
    'change_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('change_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<String> discountApprovedByUserId =
      GeneratedColumn<String>(
        'discount_approved_by_user_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<DateTime> discountApprovedAt =
      GeneratedColumn<DateTime>(
        'discount_approved_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('version >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    registerId,
    shiftId,
    inventoryTransactionId,
    operationId,
    receiptNumber,
    status,
    cashierUserId,
    subtotalMinor,
    discountMinor,
    taxMinor,
    totalMinor,
    tenderedMinor,
    changeMinor,
    discountApprovedByUserId,
    discountApprovedAt,
    completedAt,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, operationId},
    {organizationId, branchId, receiptNumber},
    {id, organizationId, branchId},
  ];
  @override
  SalesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SalesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      registerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}register_id'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift_id'],
      ),
      inventoryTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inventory_transaction_id'],
      ),
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      receiptNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_number'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      cashierUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cashier_user_id'],
      )!,
      subtotalMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subtotal_minor'],
      )!,
      discountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_minor'],
      )!,
      taxMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax_minor'],
      )!,
      totalMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_minor'],
      )!,
      tenderedMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tendered_minor'],
      )!,
      changeMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_minor'],
      )!,
      discountApprovedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}discount_approved_by_user_id'],
      ),
      discountApprovedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}discount_approved_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  Sales createAlias(String alias) {
    return Sales(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (register_id, organization_id, branch_id) REFERENCES registers (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (shift_id, organization_id, branch_id) REFERENCES shifts (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (inventory_transaction_id, organization_id, branch_id) REFERENCES inventory_transactions (id, organization_id, branch_id) ON DELETE RESTRICT',
    'CHECK (status IN (\'draft\', \'completed\', \'voided\', \'partially_returned\', \'returned\', \'sync_rejected\'))',
    'CHECK ((status = \'draft\' AND completed_at IS NULL) OR (status <> \'draft\' AND completed_at IS NOT NULL))',
    'CHECK (discount_minor <= subtotal_minor)',
  ];
}

class SalesData extends DataClass implements Insertable<SalesData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String registerId;
  final String? shiftId;
  final String? inventoryTransactionId;
  final String operationId;
  final String? receiptNumber;
  final String status;
  final String cashierUserId;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
  final int tenderedMinor;
  final int changeMinor;
  final String? discountApprovedByUserId;
  final DateTime? discountApprovedAt;
  final DateTime? completedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SalesData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.registerId,
    this.shiftId,
    this.inventoryTransactionId,
    required this.operationId,
    this.receiptNumber,
    required this.status,
    required this.cashierUserId,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
    required this.tenderedMinor,
    required this.changeMinor,
    this.discountApprovedByUserId,
    this.discountApprovedAt,
    this.completedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['register_id'] = Variable<String>(registerId);
    if (!nullToAbsent || shiftId != null) {
      map['shift_id'] = Variable<String>(shiftId);
    }
    if (!nullToAbsent || inventoryTransactionId != null) {
      map['inventory_transaction_id'] = Variable<String>(
        inventoryTransactionId,
      );
    }
    map['operation_id'] = Variable<String>(operationId);
    if (!nullToAbsent || receiptNumber != null) {
      map['receipt_number'] = Variable<String>(receiptNumber);
    }
    map['status'] = Variable<String>(status);
    map['cashier_user_id'] = Variable<String>(cashierUserId);
    map['subtotal_minor'] = Variable<int>(subtotalMinor);
    map['discount_minor'] = Variable<int>(discountMinor);
    map['tax_minor'] = Variable<int>(taxMinor);
    map['total_minor'] = Variable<int>(totalMinor);
    map['tendered_minor'] = Variable<int>(tenderedMinor);
    map['change_minor'] = Variable<int>(changeMinor);
    if (!nullToAbsent || discountApprovedByUserId != null) {
      map['discount_approved_by_user_id'] = Variable<String>(
        discountApprovedByUserId,
      );
    }
    if (!nullToAbsent || discountApprovedAt != null) {
      map['discount_approved_at'] = Variable<DateTime>(discountApprovedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      registerId: Value(registerId),
      shiftId: shiftId == null && nullToAbsent
          ? const Value.absent()
          : Value(shiftId),
      inventoryTransactionId: inventoryTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(inventoryTransactionId),
      operationId: Value(operationId),
      receiptNumber: receiptNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptNumber),
      status: Value(status),
      cashierUserId: Value(cashierUserId),
      subtotalMinor: Value(subtotalMinor),
      discountMinor: Value(discountMinor),
      taxMinor: Value(taxMinor),
      totalMinor: Value(totalMinor),
      tenderedMinor: Value(tenderedMinor),
      changeMinor: Value(changeMinor),
      discountApprovedByUserId: discountApprovedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(discountApprovedByUserId),
      discountApprovedAt: discountApprovedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(discountApprovedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SalesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SalesData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      registerId: serializer.fromJson<String>(json['registerId']),
      shiftId: serializer.fromJson<String?>(json['shiftId']),
      inventoryTransactionId: serializer.fromJson<String?>(
        json['inventoryTransactionId'],
      ),
      operationId: serializer.fromJson<String>(json['operationId']),
      receiptNumber: serializer.fromJson<String?>(json['receiptNumber']),
      status: serializer.fromJson<String>(json['status']),
      cashierUserId: serializer.fromJson<String>(json['cashierUserId']),
      subtotalMinor: serializer.fromJson<int>(json['subtotalMinor']),
      discountMinor: serializer.fromJson<int>(json['discountMinor']),
      taxMinor: serializer.fromJson<int>(json['taxMinor']),
      totalMinor: serializer.fromJson<int>(json['totalMinor']),
      tenderedMinor: serializer.fromJson<int>(json['tenderedMinor']),
      changeMinor: serializer.fromJson<int>(json['changeMinor']),
      discountApprovedByUserId: serializer.fromJson<String?>(
        json['discountApprovedByUserId'],
      ),
      discountApprovedAt: serializer.fromJson<DateTime?>(
        json['discountApprovedAt'],
      ),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'registerId': serializer.toJson<String>(registerId),
      'shiftId': serializer.toJson<String?>(shiftId),
      'inventoryTransactionId': serializer.toJson<String?>(
        inventoryTransactionId,
      ),
      'operationId': serializer.toJson<String>(operationId),
      'receiptNumber': serializer.toJson<String?>(receiptNumber),
      'status': serializer.toJson<String>(status),
      'cashierUserId': serializer.toJson<String>(cashierUserId),
      'subtotalMinor': serializer.toJson<int>(subtotalMinor),
      'discountMinor': serializer.toJson<int>(discountMinor),
      'taxMinor': serializer.toJson<int>(taxMinor),
      'totalMinor': serializer.toJson<int>(totalMinor),
      'tenderedMinor': serializer.toJson<int>(tenderedMinor),
      'changeMinor': serializer.toJson<int>(changeMinor),
      'discountApprovedByUserId': serializer.toJson<String?>(
        discountApprovedByUserId,
      ),
      'discountApprovedAt': serializer.toJson<DateTime?>(discountApprovedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SalesData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? registerId,
    Value<String?> shiftId = const Value.absent(),
    Value<String?> inventoryTransactionId = const Value.absent(),
    String? operationId,
    Value<String?> receiptNumber = const Value.absent(),
    String? status,
    String? cashierUserId,
    int? subtotalMinor,
    int? discountMinor,
    int? taxMinor,
    int? totalMinor,
    int? tenderedMinor,
    int? changeMinor,
    Value<String?> discountApprovedByUserId = const Value.absent(),
    Value<DateTime?> discountApprovedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SalesData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    registerId: registerId ?? this.registerId,
    shiftId: shiftId.present ? shiftId.value : this.shiftId,
    inventoryTransactionId: inventoryTransactionId.present
        ? inventoryTransactionId.value
        : this.inventoryTransactionId,
    operationId: operationId ?? this.operationId,
    receiptNumber: receiptNumber.present
        ? receiptNumber.value
        : this.receiptNumber,
    status: status ?? this.status,
    cashierUserId: cashierUserId ?? this.cashierUserId,
    subtotalMinor: subtotalMinor ?? this.subtotalMinor,
    discountMinor: discountMinor ?? this.discountMinor,
    taxMinor: taxMinor ?? this.taxMinor,
    totalMinor: totalMinor ?? this.totalMinor,
    tenderedMinor: tenderedMinor ?? this.tenderedMinor,
    changeMinor: changeMinor ?? this.changeMinor,
    discountApprovedByUserId: discountApprovedByUserId.present
        ? discountApprovedByUserId.value
        : this.discountApprovedByUserId,
    discountApprovedAt: discountApprovedAt.present
        ? discountApprovedAt.value
        : this.discountApprovedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SalesData copyWithCompanion(SalesCompanion data) {
    return SalesData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      registerId: data.registerId.present
          ? data.registerId.value
          : this.registerId,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      inventoryTransactionId: data.inventoryTransactionId.present
          ? data.inventoryTransactionId.value
          : this.inventoryTransactionId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      receiptNumber: data.receiptNumber.present
          ? data.receiptNumber.value
          : this.receiptNumber,
      status: data.status.present ? data.status.value : this.status,
      cashierUserId: data.cashierUserId.present
          ? data.cashierUserId.value
          : this.cashierUserId,
      subtotalMinor: data.subtotalMinor.present
          ? data.subtotalMinor.value
          : this.subtotalMinor,
      discountMinor: data.discountMinor.present
          ? data.discountMinor.value
          : this.discountMinor,
      taxMinor: data.taxMinor.present ? data.taxMinor.value : this.taxMinor,
      totalMinor: data.totalMinor.present
          ? data.totalMinor.value
          : this.totalMinor,
      tenderedMinor: data.tenderedMinor.present
          ? data.tenderedMinor.value
          : this.tenderedMinor,
      changeMinor: data.changeMinor.present
          ? data.changeMinor.value
          : this.changeMinor,
      discountApprovedByUserId: data.discountApprovedByUserId.present
          ? data.discountApprovedByUserId.value
          : this.discountApprovedByUserId,
      discountApprovedAt: data.discountApprovedAt.present
          ? data.discountApprovedAt.value
          : this.discountApprovedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SalesData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('registerId: $registerId, ')
          ..write('shiftId: $shiftId, ')
          ..write('inventoryTransactionId: $inventoryTransactionId, ')
          ..write('operationId: $operationId, ')
          ..write('receiptNumber: $receiptNumber, ')
          ..write('status: $status, ')
          ..write('cashierUserId: $cashierUserId, ')
          ..write('subtotalMinor: $subtotalMinor, ')
          ..write('discountMinor: $discountMinor, ')
          ..write('taxMinor: $taxMinor, ')
          ..write('totalMinor: $totalMinor, ')
          ..write('tenderedMinor: $tenderedMinor, ')
          ..write('changeMinor: $changeMinor, ')
          ..write('discountApprovedByUserId: $discountApprovedByUserId, ')
          ..write('discountApprovedAt: $discountApprovedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    organizationId,
    branchId,
    registerId,
    shiftId,
    inventoryTransactionId,
    operationId,
    receiptNumber,
    status,
    cashierUserId,
    subtotalMinor,
    discountMinor,
    taxMinor,
    totalMinor,
    tenderedMinor,
    changeMinor,
    discountApprovedByUserId,
    discountApprovedAt,
    completedAt,
    version,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SalesData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.registerId == this.registerId &&
          other.shiftId == this.shiftId &&
          other.inventoryTransactionId == this.inventoryTransactionId &&
          other.operationId == this.operationId &&
          other.receiptNumber == this.receiptNumber &&
          other.status == this.status &&
          other.cashierUserId == this.cashierUserId &&
          other.subtotalMinor == this.subtotalMinor &&
          other.discountMinor == this.discountMinor &&
          other.taxMinor == this.taxMinor &&
          other.totalMinor == this.totalMinor &&
          other.tenderedMinor == this.tenderedMinor &&
          other.changeMinor == this.changeMinor &&
          other.discountApprovedByUserId == this.discountApprovedByUserId &&
          other.discountApprovedAt == this.discountApprovedAt &&
          other.completedAt == this.completedAt &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SalesCompanion extends UpdateCompanion<SalesData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> registerId;
  final Value<String?> shiftId;
  final Value<String?> inventoryTransactionId;
  final Value<String> operationId;
  final Value<String?> receiptNumber;
  final Value<String> status;
  final Value<String> cashierUserId;
  final Value<int> subtotalMinor;
  final Value<int> discountMinor;
  final Value<int> taxMinor;
  final Value<int> totalMinor;
  final Value<int> tenderedMinor;
  final Value<int> changeMinor;
  final Value<String?> discountApprovedByUserId;
  final Value<DateTime?> discountApprovedAt;
  final Value<DateTime?> completedAt;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.registerId = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.inventoryTransactionId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.receiptNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.cashierUserId = const Value.absent(),
    this.subtotalMinor = const Value.absent(),
    this.discountMinor = const Value.absent(),
    this.taxMinor = const Value.absent(),
    this.totalMinor = const Value.absent(),
    this.tenderedMinor = const Value.absent(),
    this.changeMinor = const Value.absent(),
    this.discountApprovedByUserId = const Value.absent(),
    this.discountApprovedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalesCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String registerId,
    this.shiftId = const Value.absent(),
    this.inventoryTransactionId = const Value.absent(),
    required String operationId,
    this.receiptNumber = const Value.absent(),
    this.status = const Value.absent(),
    required String cashierUserId,
    this.subtotalMinor = const Value.absent(),
    this.discountMinor = const Value.absent(),
    this.taxMinor = const Value.absent(),
    this.totalMinor = const Value.absent(),
    this.tenderedMinor = const Value.absent(),
    this.changeMinor = const Value.absent(),
    this.discountApprovedByUserId = const Value.absent(),
    this.discountApprovedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       registerId = Value(registerId),
       operationId = Value(operationId),
       cashierUserId = Value(cashierUserId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SalesData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? registerId,
    Expression<String>? shiftId,
    Expression<String>? inventoryTransactionId,
    Expression<String>? operationId,
    Expression<String>? receiptNumber,
    Expression<String>? status,
    Expression<String>? cashierUserId,
    Expression<int>? subtotalMinor,
    Expression<int>? discountMinor,
    Expression<int>? taxMinor,
    Expression<int>? totalMinor,
    Expression<int>? tenderedMinor,
    Expression<int>? changeMinor,
    Expression<String>? discountApprovedByUserId,
    Expression<DateTime>? discountApprovedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (registerId != null) 'register_id': registerId,
      if (shiftId != null) 'shift_id': shiftId,
      if (inventoryTransactionId != null)
        'inventory_transaction_id': inventoryTransactionId,
      if (operationId != null) 'operation_id': operationId,
      if (receiptNumber != null) 'receipt_number': receiptNumber,
      if (status != null) 'status': status,
      if (cashierUserId != null) 'cashier_user_id': cashierUserId,
      if (subtotalMinor != null) 'subtotal_minor': subtotalMinor,
      if (discountMinor != null) 'discount_minor': discountMinor,
      if (taxMinor != null) 'tax_minor': taxMinor,
      if (totalMinor != null) 'total_minor': totalMinor,
      if (tenderedMinor != null) 'tendered_minor': tenderedMinor,
      if (changeMinor != null) 'change_minor': changeMinor,
      if (discountApprovedByUserId != null)
        'discount_approved_by_user_id': discountApprovedByUserId,
      if (discountApprovedAt != null)
        'discount_approved_at': discountApprovedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalesCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? registerId,
    Value<String?>? shiftId,
    Value<String?>? inventoryTransactionId,
    Value<String>? operationId,
    Value<String?>? receiptNumber,
    Value<String>? status,
    Value<String>? cashierUserId,
    Value<int>? subtotalMinor,
    Value<int>? discountMinor,
    Value<int>? taxMinor,
    Value<int>? totalMinor,
    Value<int>? tenderedMinor,
    Value<int>? changeMinor,
    Value<String?>? discountApprovedByUserId,
    Value<DateTime?>? discountApprovedAt,
    Value<DateTime?>? completedAt,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SalesCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      registerId: registerId ?? this.registerId,
      shiftId: shiftId ?? this.shiftId,
      inventoryTransactionId:
          inventoryTransactionId ?? this.inventoryTransactionId,
      operationId: operationId ?? this.operationId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      status: status ?? this.status,
      cashierUserId: cashierUserId ?? this.cashierUserId,
      subtotalMinor: subtotalMinor ?? this.subtotalMinor,
      discountMinor: discountMinor ?? this.discountMinor,
      taxMinor: taxMinor ?? this.taxMinor,
      totalMinor: totalMinor ?? this.totalMinor,
      tenderedMinor: tenderedMinor ?? this.tenderedMinor,
      changeMinor: changeMinor ?? this.changeMinor,
      discountApprovedByUserId:
          discountApprovedByUserId ?? this.discountApprovedByUserId,
      discountApprovedAt: discountApprovedAt ?? this.discountApprovedAt,
      completedAt: completedAt ?? this.completedAt,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (registerId.present) {
      map['register_id'] = Variable<String>(registerId.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<String>(shiftId.value);
    }
    if (inventoryTransactionId.present) {
      map['inventory_transaction_id'] = Variable<String>(
        inventoryTransactionId.value,
      );
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (receiptNumber.present) {
      map['receipt_number'] = Variable<String>(receiptNumber.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (cashierUserId.present) {
      map['cashier_user_id'] = Variable<String>(cashierUserId.value);
    }
    if (subtotalMinor.present) {
      map['subtotal_minor'] = Variable<int>(subtotalMinor.value);
    }
    if (discountMinor.present) {
      map['discount_minor'] = Variable<int>(discountMinor.value);
    }
    if (taxMinor.present) {
      map['tax_minor'] = Variable<int>(taxMinor.value);
    }
    if (totalMinor.present) {
      map['total_minor'] = Variable<int>(totalMinor.value);
    }
    if (tenderedMinor.present) {
      map['tendered_minor'] = Variable<int>(tenderedMinor.value);
    }
    if (changeMinor.present) {
      map['change_minor'] = Variable<int>(changeMinor.value);
    }
    if (discountApprovedByUserId.present) {
      map['discount_approved_by_user_id'] = Variable<String>(
        discountApprovedByUserId.value,
      );
    }
    if (discountApprovedAt.present) {
      map['discount_approved_at'] = Variable<DateTime>(
        discountApprovedAt.value,
      );
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('registerId: $registerId, ')
          ..write('shiftId: $shiftId, ')
          ..write('inventoryTransactionId: $inventoryTransactionId, ')
          ..write('operationId: $operationId, ')
          ..write('receiptNumber: $receiptNumber, ')
          ..write('status: $status, ')
          ..write('cashierUserId: $cashierUserId, ')
          ..write('subtotalMinor: $subtotalMinor, ')
          ..write('discountMinor: $discountMinor, ')
          ..write('taxMinor: $taxMinor, ')
          ..write('totalMinor: $totalMinor, ')
          ..write('tenderedMinor: $tenderedMinor, ')
          ..write('changeMinor: $changeMinor, ')
          ..write('discountApprovedByUserId: $discountApprovedByUserId, ')
          ..write('discountApprovedAt: $discountApprovedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SaleItems extends Table with TableInfo<SaleItems, SaleItemsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SaleItems(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sales (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> stockLocationId = GeneratedColumn<String>(
    'stock_location_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stock_locations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<int> lineNumber = GeneratedColumn<int>(
    'line_number',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('line_number > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> productNameSnapshot =
      GeneratedColumn<String>(
        'product_name_snapshot',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<String> skuSnapshot = GeneratedColumn<String>(
    'sku_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> barcodeSnapshot = GeneratedColumn<String>(
    'barcode_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> unitNameSnapshot = GeneratedColumn<String>(
    'unit_name_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> quantityMilli = GeneratedColumn<int>(
    'quantity_milli',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('quantity_milli > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> unitPriceMinorSnapshot = GeneratedColumn<int>(
    'unit_price_minor_snapshot',
    aliasedName,
    false,
    check: () =>
        const i2.CustomExpression<bool>('unit_price_minor_snapshot >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> unitCostMinorSnapshot = GeneratedColumn<int>(
    'unit_cost_minor_snapshot',
    aliasedName,
    false,
    check: () =>
        const i2.CustomExpression<bool>('unit_cost_minor_snapshot >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> taxRateBasisPointsSnapshot =
      GeneratedColumn<int>(
        'tax_rate_basis_points_snapshot',
        aliasedName,
        false,
        check: () => const i2.CustomExpression<bool>(
          'tax_rate_basis_points_snapshot >= 0 AND '
          'tax_rate_basis_points_snapshot <= 10000',
        ),
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<bool> taxInclusiveSnapshot = GeneratedColumn<bool>(
    'tax_inclusive_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tax_inclusive_snapshot" IN (0, 1))',
    ),
  );
  late final GeneratedColumn<int> grossAmountMinor = GeneratedColumn<int>(
    'gross_amount_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('gross_amount_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> discountAmountMinor = GeneratedColumn<int>(
    'discount_amount_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('discount_amount_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> netAmountMinor = GeneratedColumn<int>(
    'net_amount_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('net_amount_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> taxAmountMinor = GeneratedColumn<int>(
    'tax_amount_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('tax_amount_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> totalAmountMinor = GeneratedColumn<int>(
    'total_amount_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('total_amount_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    saleId,
    productId,
    stockLocationId,
    lineNumber,
    productNameSnapshot,
    skuSnapshot,
    barcodeSnapshot,
    unitNameSnapshot,
    quantityMilli,
    unitPriceMinorSnapshot,
    unitCostMinorSnapshot,
    taxRateBasisPointsSnapshot,
    taxInclusiveSnapshot,
    grossAmountMinor,
    discountAmountMinor,
    netAmountMinor,
    taxAmountMinor,
    totalAmountMinor,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sale_items';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {saleId, lineNumber},
    {id, saleId},
    {id, organizationId, branchId},
  ];
  @override
  SaleItemsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleItemsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      stockLocationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stock_location_id'],
      )!,
      lineNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_number'],
      )!,
      productNameSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name_snapshot'],
      )!,
      skuSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku_snapshot'],
      )!,
      barcodeSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode_snapshot'],
      ),
      unitNameSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_name_snapshot'],
      )!,
      quantityMilli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity_milli'],
      )!,
      unitPriceMinorSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_minor_snapshot'],
      )!,
      unitCostMinorSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_cost_minor_snapshot'],
      )!,
      taxRateBasisPointsSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax_rate_basis_points_snapshot'],
      )!,
      taxInclusiveSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tax_inclusive_snapshot'],
      )!,
      grossAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gross_amount_minor'],
      )!,
      discountAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_amount_minor'],
      )!,
      netAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}net_amount_minor'],
      )!,
      taxAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax_amount_minor'],
      )!,
      totalAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_amount_minor'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  SaleItems createAlias(String alias) {
    return SaleItems(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_id, organization_id, branch_id) REFERENCES sales (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (product_id, organization_id) REFERENCES products (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (stock_location_id, organization_id, branch_id) REFERENCES stock_locations (id, organization_id, branch_id) ON DELETE RESTRICT',
    'CHECK (discount_amount_minor <= gross_amount_minor)',
  ];
}

class SaleItemsData extends DataClass implements Insertable<SaleItemsData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String saleId;
  final String productId;
  final String stockLocationId;
  final int lineNumber;
  final String productNameSnapshot;
  final String skuSnapshot;
  final String? barcodeSnapshot;
  final String unitNameSnapshot;
  final int quantityMilli;
  final int unitPriceMinorSnapshot;
  final int unitCostMinorSnapshot;
  final int taxRateBasisPointsSnapshot;
  final bool taxInclusiveSnapshot;
  final int grossAmountMinor;
  final int discountAmountMinor;
  final int netAmountMinor;
  final int taxAmountMinor;
  final int totalAmountMinor;
  final DateTime createdAt;
  const SaleItemsData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.saleId,
    required this.productId,
    required this.stockLocationId,
    required this.lineNumber,
    required this.productNameSnapshot,
    required this.skuSnapshot,
    this.barcodeSnapshot,
    required this.unitNameSnapshot,
    required this.quantityMilli,
    required this.unitPriceMinorSnapshot,
    required this.unitCostMinorSnapshot,
    required this.taxRateBasisPointsSnapshot,
    required this.taxInclusiveSnapshot,
    required this.grossAmountMinor,
    required this.discountAmountMinor,
    required this.netAmountMinor,
    required this.taxAmountMinor,
    required this.totalAmountMinor,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['sale_id'] = Variable<String>(saleId);
    map['product_id'] = Variable<String>(productId);
    map['stock_location_id'] = Variable<String>(stockLocationId);
    map['line_number'] = Variable<int>(lineNumber);
    map['product_name_snapshot'] = Variable<String>(productNameSnapshot);
    map['sku_snapshot'] = Variable<String>(skuSnapshot);
    if (!nullToAbsent || barcodeSnapshot != null) {
      map['barcode_snapshot'] = Variable<String>(barcodeSnapshot);
    }
    map['unit_name_snapshot'] = Variable<String>(unitNameSnapshot);
    map['quantity_milli'] = Variable<int>(quantityMilli);
    map['unit_price_minor_snapshot'] = Variable<int>(unitPriceMinorSnapshot);
    map['unit_cost_minor_snapshot'] = Variable<int>(unitCostMinorSnapshot);
    map['tax_rate_basis_points_snapshot'] = Variable<int>(
      taxRateBasisPointsSnapshot,
    );
    map['tax_inclusive_snapshot'] = Variable<bool>(taxInclusiveSnapshot);
    map['gross_amount_minor'] = Variable<int>(grossAmountMinor);
    map['discount_amount_minor'] = Variable<int>(discountAmountMinor);
    map['net_amount_minor'] = Variable<int>(netAmountMinor);
    map['tax_amount_minor'] = Variable<int>(taxAmountMinor);
    map['total_amount_minor'] = Variable<int>(totalAmountMinor);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SaleItemsCompanion toCompanion(bool nullToAbsent) {
    return SaleItemsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      saleId: Value(saleId),
      productId: Value(productId),
      stockLocationId: Value(stockLocationId),
      lineNumber: Value(lineNumber),
      productNameSnapshot: Value(productNameSnapshot),
      skuSnapshot: Value(skuSnapshot),
      barcodeSnapshot: barcodeSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(barcodeSnapshot),
      unitNameSnapshot: Value(unitNameSnapshot),
      quantityMilli: Value(quantityMilli),
      unitPriceMinorSnapshot: Value(unitPriceMinorSnapshot),
      unitCostMinorSnapshot: Value(unitCostMinorSnapshot),
      taxRateBasisPointsSnapshot: Value(taxRateBasisPointsSnapshot),
      taxInclusiveSnapshot: Value(taxInclusiveSnapshot),
      grossAmountMinor: Value(grossAmountMinor),
      discountAmountMinor: Value(discountAmountMinor),
      netAmountMinor: Value(netAmountMinor),
      taxAmountMinor: Value(taxAmountMinor),
      totalAmountMinor: Value(totalAmountMinor),
      createdAt: Value(createdAt),
    );
  }

  factory SaleItemsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleItemsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      saleId: serializer.fromJson<String>(json['saleId']),
      productId: serializer.fromJson<String>(json['productId']),
      stockLocationId: serializer.fromJson<String>(json['stockLocationId']),
      lineNumber: serializer.fromJson<int>(json['lineNumber']),
      productNameSnapshot: serializer.fromJson<String>(
        json['productNameSnapshot'],
      ),
      skuSnapshot: serializer.fromJson<String>(json['skuSnapshot']),
      barcodeSnapshot: serializer.fromJson<String?>(json['barcodeSnapshot']),
      unitNameSnapshot: serializer.fromJson<String>(json['unitNameSnapshot']),
      quantityMilli: serializer.fromJson<int>(json['quantityMilli']),
      unitPriceMinorSnapshot: serializer.fromJson<int>(
        json['unitPriceMinorSnapshot'],
      ),
      unitCostMinorSnapshot: serializer.fromJson<int>(
        json['unitCostMinorSnapshot'],
      ),
      taxRateBasisPointsSnapshot: serializer.fromJson<int>(
        json['taxRateBasisPointsSnapshot'],
      ),
      taxInclusiveSnapshot: serializer.fromJson<bool>(
        json['taxInclusiveSnapshot'],
      ),
      grossAmountMinor: serializer.fromJson<int>(json['grossAmountMinor']),
      discountAmountMinor: serializer.fromJson<int>(
        json['discountAmountMinor'],
      ),
      netAmountMinor: serializer.fromJson<int>(json['netAmountMinor']),
      taxAmountMinor: serializer.fromJson<int>(json['taxAmountMinor']),
      totalAmountMinor: serializer.fromJson<int>(json['totalAmountMinor']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'saleId': serializer.toJson<String>(saleId),
      'productId': serializer.toJson<String>(productId),
      'stockLocationId': serializer.toJson<String>(stockLocationId),
      'lineNumber': serializer.toJson<int>(lineNumber),
      'productNameSnapshot': serializer.toJson<String>(productNameSnapshot),
      'skuSnapshot': serializer.toJson<String>(skuSnapshot),
      'barcodeSnapshot': serializer.toJson<String?>(barcodeSnapshot),
      'unitNameSnapshot': serializer.toJson<String>(unitNameSnapshot),
      'quantityMilli': serializer.toJson<int>(quantityMilli),
      'unitPriceMinorSnapshot': serializer.toJson<int>(unitPriceMinorSnapshot),
      'unitCostMinorSnapshot': serializer.toJson<int>(unitCostMinorSnapshot),
      'taxRateBasisPointsSnapshot': serializer.toJson<int>(
        taxRateBasisPointsSnapshot,
      ),
      'taxInclusiveSnapshot': serializer.toJson<bool>(taxInclusiveSnapshot),
      'grossAmountMinor': serializer.toJson<int>(grossAmountMinor),
      'discountAmountMinor': serializer.toJson<int>(discountAmountMinor),
      'netAmountMinor': serializer.toJson<int>(netAmountMinor),
      'taxAmountMinor': serializer.toJson<int>(taxAmountMinor),
      'totalAmountMinor': serializer.toJson<int>(totalAmountMinor),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SaleItemsData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? saleId,
    String? productId,
    String? stockLocationId,
    int? lineNumber,
    String? productNameSnapshot,
    String? skuSnapshot,
    Value<String?> barcodeSnapshot = const Value.absent(),
    String? unitNameSnapshot,
    int? quantityMilli,
    int? unitPriceMinorSnapshot,
    int? unitCostMinorSnapshot,
    int? taxRateBasisPointsSnapshot,
    bool? taxInclusiveSnapshot,
    int? grossAmountMinor,
    int? discountAmountMinor,
    int? netAmountMinor,
    int? taxAmountMinor,
    int? totalAmountMinor,
    DateTime? createdAt,
  }) => SaleItemsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    saleId: saleId ?? this.saleId,
    productId: productId ?? this.productId,
    stockLocationId: stockLocationId ?? this.stockLocationId,
    lineNumber: lineNumber ?? this.lineNumber,
    productNameSnapshot: productNameSnapshot ?? this.productNameSnapshot,
    skuSnapshot: skuSnapshot ?? this.skuSnapshot,
    barcodeSnapshot: barcodeSnapshot.present
        ? barcodeSnapshot.value
        : this.barcodeSnapshot,
    unitNameSnapshot: unitNameSnapshot ?? this.unitNameSnapshot,
    quantityMilli: quantityMilli ?? this.quantityMilli,
    unitPriceMinorSnapshot:
        unitPriceMinorSnapshot ?? this.unitPriceMinorSnapshot,
    unitCostMinorSnapshot: unitCostMinorSnapshot ?? this.unitCostMinorSnapshot,
    taxRateBasisPointsSnapshot:
        taxRateBasisPointsSnapshot ?? this.taxRateBasisPointsSnapshot,
    taxInclusiveSnapshot: taxInclusiveSnapshot ?? this.taxInclusiveSnapshot,
    grossAmountMinor: grossAmountMinor ?? this.grossAmountMinor,
    discountAmountMinor: discountAmountMinor ?? this.discountAmountMinor,
    netAmountMinor: netAmountMinor ?? this.netAmountMinor,
    taxAmountMinor: taxAmountMinor ?? this.taxAmountMinor,
    totalAmountMinor: totalAmountMinor ?? this.totalAmountMinor,
    createdAt: createdAt ?? this.createdAt,
  );
  SaleItemsData copyWithCompanion(SaleItemsCompanion data) {
    return SaleItemsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      productId: data.productId.present ? data.productId.value : this.productId,
      stockLocationId: data.stockLocationId.present
          ? data.stockLocationId.value
          : this.stockLocationId,
      lineNumber: data.lineNumber.present
          ? data.lineNumber.value
          : this.lineNumber,
      productNameSnapshot: data.productNameSnapshot.present
          ? data.productNameSnapshot.value
          : this.productNameSnapshot,
      skuSnapshot: data.skuSnapshot.present
          ? data.skuSnapshot.value
          : this.skuSnapshot,
      barcodeSnapshot: data.barcodeSnapshot.present
          ? data.barcodeSnapshot.value
          : this.barcodeSnapshot,
      unitNameSnapshot: data.unitNameSnapshot.present
          ? data.unitNameSnapshot.value
          : this.unitNameSnapshot,
      quantityMilli: data.quantityMilli.present
          ? data.quantityMilli.value
          : this.quantityMilli,
      unitPriceMinorSnapshot: data.unitPriceMinorSnapshot.present
          ? data.unitPriceMinorSnapshot.value
          : this.unitPriceMinorSnapshot,
      unitCostMinorSnapshot: data.unitCostMinorSnapshot.present
          ? data.unitCostMinorSnapshot.value
          : this.unitCostMinorSnapshot,
      taxRateBasisPointsSnapshot: data.taxRateBasisPointsSnapshot.present
          ? data.taxRateBasisPointsSnapshot.value
          : this.taxRateBasisPointsSnapshot,
      taxInclusiveSnapshot: data.taxInclusiveSnapshot.present
          ? data.taxInclusiveSnapshot.value
          : this.taxInclusiveSnapshot,
      grossAmountMinor: data.grossAmountMinor.present
          ? data.grossAmountMinor.value
          : this.grossAmountMinor,
      discountAmountMinor: data.discountAmountMinor.present
          ? data.discountAmountMinor.value
          : this.discountAmountMinor,
      netAmountMinor: data.netAmountMinor.present
          ? data.netAmountMinor.value
          : this.netAmountMinor,
      taxAmountMinor: data.taxAmountMinor.present
          ? data.taxAmountMinor.value
          : this.taxAmountMinor,
      totalAmountMinor: data.totalAmountMinor.present
          ? data.totalAmountMinor.value
          : this.totalAmountMinor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleItemsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('saleId: $saleId, ')
          ..write('productId: $productId, ')
          ..write('stockLocationId: $stockLocationId, ')
          ..write('lineNumber: $lineNumber, ')
          ..write('productNameSnapshot: $productNameSnapshot, ')
          ..write('skuSnapshot: $skuSnapshot, ')
          ..write('barcodeSnapshot: $barcodeSnapshot, ')
          ..write('unitNameSnapshot: $unitNameSnapshot, ')
          ..write('quantityMilli: $quantityMilli, ')
          ..write('unitPriceMinorSnapshot: $unitPriceMinorSnapshot, ')
          ..write('unitCostMinorSnapshot: $unitCostMinorSnapshot, ')
          ..write('taxRateBasisPointsSnapshot: $taxRateBasisPointsSnapshot, ')
          ..write('taxInclusiveSnapshot: $taxInclusiveSnapshot, ')
          ..write('grossAmountMinor: $grossAmountMinor, ')
          ..write('discountAmountMinor: $discountAmountMinor, ')
          ..write('netAmountMinor: $netAmountMinor, ')
          ..write('taxAmountMinor: $taxAmountMinor, ')
          ..write('totalAmountMinor: $totalAmountMinor, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    organizationId,
    branchId,
    saleId,
    productId,
    stockLocationId,
    lineNumber,
    productNameSnapshot,
    skuSnapshot,
    barcodeSnapshot,
    unitNameSnapshot,
    quantityMilli,
    unitPriceMinorSnapshot,
    unitCostMinorSnapshot,
    taxRateBasisPointsSnapshot,
    taxInclusiveSnapshot,
    grossAmountMinor,
    discountAmountMinor,
    netAmountMinor,
    taxAmountMinor,
    totalAmountMinor,
    createdAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleItemsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.saleId == this.saleId &&
          other.productId == this.productId &&
          other.stockLocationId == this.stockLocationId &&
          other.lineNumber == this.lineNumber &&
          other.productNameSnapshot == this.productNameSnapshot &&
          other.skuSnapshot == this.skuSnapshot &&
          other.barcodeSnapshot == this.barcodeSnapshot &&
          other.unitNameSnapshot == this.unitNameSnapshot &&
          other.quantityMilli == this.quantityMilli &&
          other.unitPriceMinorSnapshot == this.unitPriceMinorSnapshot &&
          other.unitCostMinorSnapshot == this.unitCostMinorSnapshot &&
          other.taxRateBasisPointsSnapshot == this.taxRateBasisPointsSnapshot &&
          other.taxInclusiveSnapshot == this.taxInclusiveSnapshot &&
          other.grossAmountMinor == this.grossAmountMinor &&
          other.discountAmountMinor == this.discountAmountMinor &&
          other.netAmountMinor == this.netAmountMinor &&
          other.taxAmountMinor == this.taxAmountMinor &&
          other.totalAmountMinor == this.totalAmountMinor &&
          other.createdAt == this.createdAt);
}

class SaleItemsCompanion extends UpdateCompanion<SaleItemsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> saleId;
  final Value<String> productId;
  final Value<String> stockLocationId;
  final Value<int> lineNumber;
  final Value<String> productNameSnapshot;
  final Value<String> skuSnapshot;
  final Value<String?> barcodeSnapshot;
  final Value<String> unitNameSnapshot;
  final Value<int> quantityMilli;
  final Value<int> unitPriceMinorSnapshot;
  final Value<int> unitCostMinorSnapshot;
  final Value<int> taxRateBasisPointsSnapshot;
  final Value<bool> taxInclusiveSnapshot;
  final Value<int> grossAmountMinor;
  final Value<int> discountAmountMinor;
  final Value<int> netAmountMinor;
  final Value<int> taxAmountMinor;
  final Value<int> totalAmountMinor;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SaleItemsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.saleId = const Value.absent(),
    this.productId = const Value.absent(),
    this.stockLocationId = const Value.absent(),
    this.lineNumber = const Value.absent(),
    this.productNameSnapshot = const Value.absent(),
    this.skuSnapshot = const Value.absent(),
    this.barcodeSnapshot = const Value.absent(),
    this.unitNameSnapshot = const Value.absent(),
    this.quantityMilli = const Value.absent(),
    this.unitPriceMinorSnapshot = const Value.absent(),
    this.unitCostMinorSnapshot = const Value.absent(),
    this.taxRateBasisPointsSnapshot = const Value.absent(),
    this.taxInclusiveSnapshot = const Value.absent(),
    this.grossAmountMinor = const Value.absent(),
    this.discountAmountMinor = const Value.absent(),
    this.netAmountMinor = const Value.absent(),
    this.taxAmountMinor = const Value.absent(),
    this.totalAmountMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SaleItemsCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String saleId,
    required String productId,
    required String stockLocationId,
    required int lineNumber,
    required String productNameSnapshot,
    required String skuSnapshot,
    this.barcodeSnapshot = const Value.absent(),
    required String unitNameSnapshot,
    required int quantityMilli,
    required int unitPriceMinorSnapshot,
    required int unitCostMinorSnapshot,
    required int taxRateBasisPointsSnapshot,
    required bool taxInclusiveSnapshot,
    required int grossAmountMinor,
    required int discountAmountMinor,
    required int netAmountMinor,
    required int taxAmountMinor,
    required int totalAmountMinor,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       saleId = Value(saleId),
       productId = Value(productId),
       stockLocationId = Value(stockLocationId),
       lineNumber = Value(lineNumber),
       productNameSnapshot = Value(productNameSnapshot),
       skuSnapshot = Value(skuSnapshot),
       unitNameSnapshot = Value(unitNameSnapshot),
       quantityMilli = Value(quantityMilli),
       unitPriceMinorSnapshot = Value(unitPriceMinorSnapshot),
       unitCostMinorSnapshot = Value(unitCostMinorSnapshot),
       taxRateBasisPointsSnapshot = Value(taxRateBasisPointsSnapshot),
       taxInclusiveSnapshot = Value(taxInclusiveSnapshot),
       grossAmountMinor = Value(grossAmountMinor),
       discountAmountMinor = Value(discountAmountMinor),
       netAmountMinor = Value(netAmountMinor),
       taxAmountMinor = Value(taxAmountMinor),
       totalAmountMinor = Value(totalAmountMinor),
       createdAt = Value(createdAt);
  static Insertable<SaleItemsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? saleId,
    Expression<String>? productId,
    Expression<String>? stockLocationId,
    Expression<int>? lineNumber,
    Expression<String>? productNameSnapshot,
    Expression<String>? skuSnapshot,
    Expression<String>? barcodeSnapshot,
    Expression<String>? unitNameSnapshot,
    Expression<int>? quantityMilli,
    Expression<int>? unitPriceMinorSnapshot,
    Expression<int>? unitCostMinorSnapshot,
    Expression<int>? taxRateBasisPointsSnapshot,
    Expression<bool>? taxInclusiveSnapshot,
    Expression<int>? grossAmountMinor,
    Expression<int>? discountAmountMinor,
    Expression<int>? netAmountMinor,
    Expression<int>? taxAmountMinor,
    Expression<int>? totalAmountMinor,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (saleId != null) 'sale_id': saleId,
      if (productId != null) 'product_id': productId,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      if (lineNumber != null) 'line_number': lineNumber,
      if (productNameSnapshot != null)
        'product_name_snapshot': productNameSnapshot,
      if (skuSnapshot != null) 'sku_snapshot': skuSnapshot,
      if (barcodeSnapshot != null) 'barcode_snapshot': barcodeSnapshot,
      if (unitNameSnapshot != null) 'unit_name_snapshot': unitNameSnapshot,
      if (quantityMilli != null) 'quantity_milli': quantityMilli,
      if (unitPriceMinorSnapshot != null)
        'unit_price_minor_snapshot': unitPriceMinorSnapshot,
      if (unitCostMinorSnapshot != null)
        'unit_cost_minor_snapshot': unitCostMinorSnapshot,
      if (taxRateBasisPointsSnapshot != null)
        'tax_rate_basis_points_snapshot': taxRateBasisPointsSnapshot,
      if (taxInclusiveSnapshot != null)
        'tax_inclusive_snapshot': taxInclusiveSnapshot,
      if (grossAmountMinor != null) 'gross_amount_minor': grossAmountMinor,
      if (discountAmountMinor != null)
        'discount_amount_minor': discountAmountMinor,
      if (netAmountMinor != null) 'net_amount_minor': netAmountMinor,
      if (taxAmountMinor != null) 'tax_amount_minor': taxAmountMinor,
      if (totalAmountMinor != null) 'total_amount_minor': totalAmountMinor,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SaleItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? saleId,
    Value<String>? productId,
    Value<String>? stockLocationId,
    Value<int>? lineNumber,
    Value<String>? productNameSnapshot,
    Value<String>? skuSnapshot,
    Value<String?>? barcodeSnapshot,
    Value<String>? unitNameSnapshot,
    Value<int>? quantityMilli,
    Value<int>? unitPriceMinorSnapshot,
    Value<int>? unitCostMinorSnapshot,
    Value<int>? taxRateBasisPointsSnapshot,
    Value<bool>? taxInclusiveSnapshot,
    Value<int>? grossAmountMinor,
    Value<int>? discountAmountMinor,
    Value<int>? netAmountMinor,
    Value<int>? taxAmountMinor,
    Value<int>? totalAmountMinor,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SaleItemsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      stockLocationId: stockLocationId ?? this.stockLocationId,
      lineNumber: lineNumber ?? this.lineNumber,
      productNameSnapshot: productNameSnapshot ?? this.productNameSnapshot,
      skuSnapshot: skuSnapshot ?? this.skuSnapshot,
      barcodeSnapshot: barcodeSnapshot ?? this.barcodeSnapshot,
      unitNameSnapshot: unitNameSnapshot ?? this.unitNameSnapshot,
      quantityMilli: quantityMilli ?? this.quantityMilli,
      unitPriceMinorSnapshot:
          unitPriceMinorSnapshot ?? this.unitPriceMinorSnapshot,
      unitCostMinorSnapshot:
          unitCostMinorSnapshot ?? this.unitCostMinorSnapshot,
      taxRateBasisPointsSnapshot:
          taxRateBasisPointsSnapshot ?? this.taxRateBasisPointsSnapshot,
      taxInclusiveSnapshot: taxInclusiveSnapshot ?? this.taxInclusiveSnapshot,
      grossAmountMinor: grossAmountMinor ?? this.grossAmountMinor,
      discountAmountMinor: discountAmountMinor ?? this.discountAmountMinor,
      netAmountMinor: netAmountMinor ?? this.netAmountMinor,
      taxAmountMinor: taxAmountMinor ?? this.taxAmountMinor,
      totalAmountMinor: totalAmountMinor ?? this.totalAmountMinor,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (stockLocationId.present) {
      map['stock_location_id'] = Variable<String>(stockLocationId.value);
    }
    if (lineNumber.present) {
      map['line_number'] = Variable<int>(lineNumber.value);
    }
    if (productNameSnapshot.present) {
      map['product_name_snapshot'] = Variable<String>(
        productNameSnapshot.value,
      );
    }
    if (skuSnapshot.present) {
      map['sku_snapshot'] = Variable<String>(skuSnapshot.value);
    }
    if (barcodeSnapshot.present) {
      map['barcode_snapshot'] = Variable<String>(barcodeSnapshot.value);
    }
    if (unitNameSnapshot.present) {
      map['unit_name_snapshot'] = Variable<String>(unitNameSnapshot.value);
    }
    if (quantityMilli.present) {
      map['quantity_milli'] = Variable<int>(quantityMilli.value);
    }
    if (unitPriceMinorSnapshot.present) {
      map['unit_price_minor_snapshot'] = Variable<int>(
        unitPriceMinorSnapshot.value,
      );
    }
    if (unitCostMinorSnapshot.present) {
      map['unit_cost_minor_snapshot'] = Variable<int>(
        unitCostMinorSnapshot.value,
      );
    }
    if (taxRateBasisPointsSnapshot.present) {
      map['tax_rate_basis_points_snapshot'] = Variable<int>(
        taxRateBasisPointsSnapshot.value,
      );
    }
    if (taxInclusiveSnapshot.present) {
      map['tax_inclusive_snapshot'] = Variable<bool>(
        taxInclusiveSnapshot.value,
      );
    }
    if (grossAmountMinor.present) {
      map['gross_amount_minor'] = Variable<int>(grossAmountMinor.value);
    }
    if (discountAmountMinor.present) {
      map['discount_amount_minor'] = Variable<int>(discountAmountMinor.value);
    }
    if (netAmountMinor.present) {
      map['net_amount_minor'] = Variable<int>(netAmountMinor.value);
    }
    if (taxAmountMinor.present) {
      map['tax_amount_minor'] = Variable<int>(taxAmountMinor.value);
    }
    if (totalAmountMinor.present) {
      map['total_amount_minor'] = Variable<int>(totalAmountMinor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SaleItemsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('saleId: $saleId, ')
          ..write('productId: $productId, ')
          ..write('stockLocationId: $stockLocationId, ')
          ..write('lineNumber: $lineNumber, ')
          ..write('productNameSnapshot: $productNameSnapshot, ')
          ..write('skuSnapshot: $skuSnapshot, ')
          ..write('barcodeSnapshot: $barcodeSnapshot, ')
          ..write('unitNameSnapshot: $unitNameSnapshot, ')
          ..write('quantityMilli: $quantityMilli, ')
          ..write('unitPriceMinorSnapshot: $unitPriceMinorSnapshot, ')
          ..write('unitCostMinorSnapshot: $unitCostMinorSnapshot, ')
          ..write('taxRateBasisPointsSnapshot: $taxRateBasisPointsSnapshot, ')
          ..write('taxInclusiveSnapshot: $taxInclusiveSnapshot, ')
          ..write('grossAmountMinor: $grossAmountMinor, ')
          ..write('discountAmountMinor: $discountAmountMinor, ')
          ..write('netAmountMinor: $netAmountMinor, ')
          ..write('taxAmountMinor: $taxAmountMinor, ')
          ..write('totalAmountMinor: $totalAmountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Payments extends Table with TableInfo<Payments, PaymentsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Payments(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sales (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> shiftId = GeneratedColumn<String>(
    'shift_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shifts (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> tenderedAmountMinor = GeneratedColumn<int>(
    'tendered_amount_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('tendered_amount_minor > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> appliedAmountMinor = GeneratedColumn<int>(
    'applied_amount_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('applied_amount_minor > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> changeAmountMinor = GeneratedColumn<int>(
    'change_amount_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('change_amount_minor >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    saleId,
    shiftId,
    paymentMethod,
    tenderedAmountMinor,
    appliedAmountMinor,
    changeAmountMinor,
    reference,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {saleId, paymentMethod},
  ];
  @override
  PaymentsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift_id'],
      ),
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      tenderedAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tendered_amount_minor'],
      )!,
      appliedAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}applied_amount_minor'],
      )!,
      changeAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_amount_minor'],
      )!,
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  Payments createAlias(String alias) {
    return Payments(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_id, organization_id, branch_id) REFERENCES sales (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (shift_id, organization_id, branch_id) REFERENCES shifts (id, organization_id, branch_id) ON DELETE RESTRICT',
    'CHECK (payment_method IN (\'cash\', \'card\', \'e_wallet\'))',
    'CHECK (tendered_amount_minor = applied_amount_minor + change_amount_minor)',
    'CHECK ((payment_method = \'cash\') OR change_amount_minor = 0)',
  ];
}

class PaymentsData extends DataClass implements Insertable<PaymentsData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String saleId;
  final String? shiftId;
  final String paymentMethod;
  final int tenderedAmountMinor;
  final int appliedAmountMinor;
  final int changeAmountMinor;
  final String? reference;
  final DateTime createdAt;
  const PaymentsData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.saleId,
    this.shiftId,
    required this.paymentMethod,
    required this.tenderedAmountMinor,
    required this.appliedAmountMinor,
    required this.changeAmountMinor,
    this.reference,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['sale_id'] = Variable<String>(saleId);
    if (!nullToAbsent || shiftId != null) {
      map['shift_id'] = Variable<String>(shiftId);
    }
    map['payment_method'] = Variable<String>(paymentMethod);
    map['tendered_amount_minor'] = Variable<int>(tenderedAmountMinor);
    map['applied_amount_minor'] = Variable<int>(appliedAmountMinor);
    map['change_amount_minor'] = Variable<int>(changeAmountMinor);
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<String>(reference);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      saleId: Value(saleId),
      shiftId: shiftId == null && nullToAbsent
          ? const Value.absent()
          : Value(shiftId),
      paymentMethod: Value(paymentMethod),
      tenderedAmountMinor: Value(tenderedAmountMinor),
      appliedAmountMinor: Value(appliedAmountMinor),
      changeAmountMinor: Value(changeAmountMinor),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
      createdAt: Value(createdAt),
    );
  }

  factory PaymentsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      saleId: serializer.fromJson<String>(json['saleId']),
      shiftId: serializer.fromJson<String?>(json['shiftId']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      tenderedAmountMinor: serializer.fromJson<int>(
        json['tenderedAmountMinor'],
      ),
      appliedAmountMinor: serializer.fromJson<int>(json['appliedAmountMinor']),
      changeAmountMinor: serializer.fromJson<int>(json['changeAmountMinor']),
      reference: serializer.fromJson<String?>(json['reference']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'saleId': serializer.toJson<String>(saleId),
      'shiftId': serializer.toJson<String?>(shiftId),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'tenderedAmountMinor': serializer.toJson<int>(tenderedAmountMinor),
      'appliedAmountMinor': serializer.toJson<int>(appliedAmountMinor),
      'changeAmountMinor': serializer.toJson<int>(changeAmountMinor),
      'reference': serializer.toJson<String?>(reference),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PaymentsData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? saleId,
    Value<String?> shiftId = const Value.absent(),
    String? paymentMethod,
    int? tenderedAmountMinor,
    int? appliedAmountMinor,
    int? changeAmountMinor,
    Value<String?> reference = const Value.absent(),
    DateTime? createdAt,
  }) => PaymentsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    saleId: saleId ?? this.saleId,
    shiftId: shiftId.present ? shiftId.value : this.shiftId,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    tenderedAmountMinor: tenderedAmountMinor ?? this.tenderedAmountMinor,
    appliedAmountMinor: appliedAmountMinor ?? this.appliedAmountMinor,
    changeAmountMinor: changeAmountMinor ?? this.changeAmountMinor,
    reference: reference.present ? reference.value : this.reference,
    createdAt: createdAt ?? this.createdAt,
  );
  PaymentsData copyWithCompanion(PaymentsCompanion data) {
    return PaymentsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      tenderedAmountMinor: data.tenderedAmountMinor.present
          ? data.tenderedAmountMinor.value
          : this.tenderedAmountMinor,
      appliedAmountMinor: data.appliedAmountMinor.present
          ? data.appliedAmountMinor.value
          : this.appliedAmountMinor,
      changeAmountMinor: data.changeAmountMinor.present
          ? data.changeAmountMinor.value
          : this.changeAmountMinor,
      reference: data.reference.present ? data.reference.value : this.reference,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('saleId: $saleId, ')
          ..write('shiftId: $shiftId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('tenderedAmountMinor: $tenderedAmountMinor, ')
          ..write('appliedAmountMinor: $appliedAmountMinor, ')
          ..write('changeAmountMinor: $changeAmountMinor, ')
          ..write('reference: $reference, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    saleId,
    shiftId,
    paymentMethod,
    tenderedAmountMinor,
    appliedAmountMinor,
    changeAmountMinor,
    reference,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.saleId == this.saleId &&
          other.shiftId == this.shiftId &&
          other.paymentMethod == this.paymentMethod &&
          other.tenderedAmountMinor == this.tenderedAmountMinor &&
          other.appliedAmountMinor == this.appliedAmountMinor &&
          other.changeAmountMinor == this.changeAmountMinor &&
          other.reference == this.reference &&
          other.createdAt == this.createdAt);
}

class PaymentsCompanion extends UpdateCompanion<PaymentsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> saleId;
  final Value<String?> shiftId;
  final Value<String> paymentMethod;
  final Value<int> tenderedAmountMinor;
  final Value<int> appliedAmountMinor;
  final Value<int> changeAmountMinor;
  final Value<String?> reference;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PaymentsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.saleId = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.tenderedAmountMinor = const Value.absent(),
    this.appliedAmountMinor = const Value.absent(),
    this.changeAmountMinor = const Value.absent(),
    this.reference = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentsCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String saleId,
    this.shiftId = const Value.absent(),
    required String paymentMethod,
    required int tenderedAmountMinor,
    required int appliedAmountMinor,
    this.changeAmountMinor = const Value.absent(),
    this.reference = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       saleId = Value(saleId),
       paymentMethod = Value(paymentMethod),
       tenderedAmountMinor = Value(tenderedAmountMinor),
       appliedAmountMinor = Value(appliedAmountMinor),
       createdAt = Value(createdAt);
  static Insertable<PaymentsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? saleId,
    Expression<String>? shiftId,
    Expression<String>? paymentMethod,
    Expression<int>? tenderedAmountMinor,
    Expression<int>? appliedAmountMinor,
    Expression<int>? changeAmountMinor,
    Expression<String>? reference,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (saleId != null) 'sale_id': saleId,
      if (shiftId != null) 'shift_id': shiftId,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (tenderedAmountMinor != null)
        'tendered_amount_minor': tenderedAmountMinor,
      if (appliedAmountMinor != null)
        'applied_amount_minor': appliedAmountMinor,
      if (changeAmountMinor != null) 'change_amount_minor': changeAmountMinor,
      if (reference != null) 'reference': reference,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? saleId,
    Value<String?>? shiftId,
    Value<String>? paymentMethod,
    Value<int>? tenderedAmountMinor,
    Value<int>? appliedAmountMinor,
    Value<int>? changeAmountMinor,
    Value<String?>? reference,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PaymentsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      saleId: saleId ?? this.saleId,
      shiftId: shiftId ?? this.shiftId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tenderedAmountMinor: tenderedAmountMinor ?? this.tenderedAmountMinor,
      appliedAmountMinor: appliedAmountMinor ?? this.appliedAmountMinor,
      changeAmountMinor: changeAmountMinor ?? this.changeAmountMinor,
      reference: reference ?? this.reference,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<String>(shiftId.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (tenderedAmountMinor.present) {
      map['tendered_amount_minor'] = Variable<int>(tenderedAmountMinor.value);
    }
    if (appliedAmountMinor.present) {
      map['applied_amount_minor'] = Variable<int>(appliedAmountMinor.value);
    }
    if (changeAmountMinor.present) {
      map['change_amount_minor'] = Variable<int>(changeAmountMinor.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('saleId: $saleId, ')
          ..write('shiftId: $shiftId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('tenderedAmountMinor: $tenderedAmountMinor, ')
          ..write('appliedAmountMinor: $appliedAmountMinor, ')
          ..write('changeAmountMinor: $changeAmountMinor, ')
          ..write('reference: $reference, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SaleDiscounts extends Table
    with TableInfo<SaleDiscounts, SaleDiscountsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SaleDiscounts(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sales (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> saleItemId = GeneratedColumn<String>(
    'sale_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sale_items (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> discountScope = GeneratedColumn<String>(
    'discount_scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> discountType = GeneratedColumn<String>(
    'discount_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('\'fixed_amount\''),
  );
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('amount_minor > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> approvedByUserId = GeneratedColumn<String>(
    'approved_by_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> approvedAt = GeneratedColumn<DateTime>(
    'approved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    saleId,
    saleItemId,
    discountScope,
    discountType,
    amountMinor,
    reason,
    approvedByUserId,
    approvedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sale_discounts';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SaleDiscountsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleDiscountsData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      )!,
      saleItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_item_id'],
      ),
      discountScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}discount_scope'],
      )!,
      discountType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}discount_type'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      approvedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approved_by_user_id'],
      ),
      approvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}approved_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  SaleDiscounts createAlias(String alias) {
    return SaleDiscounts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_id, organization_id, branch_id) REFERENCES sales (id, organization_id, branch_id) ON DELETE RESTRICT',
    'FOREIGN KEY (sale_item_id, sale_id) REFERENCES sale_items (id, sale_id) ON DELETE RESTRICT',
    'CHECK (discount_scope IN (\'item\', \'sale\'))',
    'CHECK (discount_type = \'fixed_amount\')',
    'CHECK ((discount_scope = \'item\' AND sale_item_id IS NOT NULL) OR (discount_scope = \'sale\' AND sale_item_id IS NULL))',
  ];
}

class SaleDiscountsData extends DataClass
    implements Insertable<SaleDiscountsData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String saleId;
  final String? saleItemId;
  final String discountScope;
  final String discountType;
  final int amountMinor;
  final String reason;
  final String? approvedByUserId;
  final DateTime? approvedAt;
  final DateTime createdAt;
  const SaleDiscountsData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.saleId,
    this.saleItemId,
    required this.discountScope,
    required this.discountType,
    required this.amountMinor,
    required this.reason,
    this.approvedByUserId,
    this.approvedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['sale_id'] = Variable<String>(saleId);
    if (!nullToAbsent || saleItemId != null) {
      map['sale_item_id'] = Variable<String>(saleItemId);
    }
    map['discount_scope'] = Variable<String>(discountScope);
    map['discount_type'] = Variable<String>(discountType);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || approvedByUserId != null) {
      map['approved_by_user_id'] = Variable<String>(approvedByUserId);
    }
    if (!nullToAbsent || approvedAt != null) {
      map['approved_at'] = Variable<DateTime>(approvedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SaleDiscountsCompanion toCompanion(bool nullToAbsent) {
    return SaleDiscountsCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      saleId: Value(saleId),
      saleItemId: saleItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(saleItemId),
      discountScope: Value(discountScope),
      discountType: Value(discountType),
      amountMinor: Value(amountMinor),
      reason: Value(reason),
      approvedByUserId: approvedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedByUserId),
      approvedAt: approvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedAt),
      createdAt: Value(createdAt),
    );
  }

  factory SaleDiscountsData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleDiscountsData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      saleId: serializer.fromJson<String>(json['saleId']),
      saleItemId: serializer.fromJson<String?>(json['saleItemId']),
      discountScope: serializer.fromJson<String>(json['discountScope']),
      discountType: serializer.fromJson<String>(json['discountType']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      reason: serializer.fromJson<String>(json['reason']),
      approvedByUserId: serializer.fromJson<String?>(json['approvedByUserId']),
      approvedAt: serializer.fromJson<DateTime?>(json['approvedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'saleId': serializer.toJson<String>(saleId),
      'saleItemId': serializer.toJson<String?>(saleItemId),
      'discountScope': serializer.toJson<String>(discountScope),
      'discountType': serializer.toJson<String>(discountType),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'reason': serializer.toJson<String>(reason),
      'approvedByUserId': serializer.toJson<String?>(approvedByUserId),
      'approvedAt': serializer.toJson<DateTime?>(approvedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SaleDiscountsData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? saleId,
    Value<String?> saleItemId = const Value.absent(),
    String? discountScope,
    String? discountType,
    int? amountMinor,
    String? reason,
    Value<String?> approvedByUserId = const Value.absent(),
    Value<DateTime?> approvedAt = const Value.absent(),
    DateTime? createdAt,
  }) => SaleDiscountsData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    saleId: saleId ?? this.saleId,
    saleItemId: saleItemId.present ? saleItemId.value : this.saleItemId,
    discountScope: discountScope ?? this.discountScope,
    discountType: discountType ?? this.discountType,
    amountMinor: amountMinor ?? this.amountMinor,
    reason: reason ?? this.reason,
    approvedByUserId: approvedByUserId.present
        ? approvedByUserId.value
        : this.approvedByUserId,
    approvedAt: approvedAt.present ? approvedAt.value : this.approvedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  SaleDiscountsData copyWithCompanion(SaleDiscountsCompanion data) {
    return SaleDiscountsData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      saleItemId: data.saleItemId.present
          ? data.saleItemId.value
          : this.saleItemId,
      discountScope: data.discountScope.present
          ? data.discountScope.value
          : this.discountScope,
      discountType: data.discountType.present
          ? data.discountType.value
          : this.discountType,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      reason: data.reason.present ? data.reason.value : this.reason,
      approvedByUserId: data.approvedByUserId.present
          ? data.approvedByUserId.value
          : this.approvedByUserId,
      approvedAt: data.approvedAt.present
          ? data.approvedAt.value
          : this.approvedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleDiscountsData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('saleId: $saleId, ')
          ..write('saleItemId: $saleItemId, ')
          ..write('discountScope: $discountScope, ')
          ..write('discountType: $discountType, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('reason: $reason, ')
          ..write('approvedByUserId: $approvedByUserId, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    saleId,
    saleItemId,
    discountScope,
    discountType,
    amountMinor,
    reason,
    approvedByUserId,
    approvedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleDiscountsData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.saleId == this.saleId &&
          other.saleItemId == this.saleItemId &&
          other.discountScope == this.discountScope &&
          other.discountType == this.discountType &&
          other.amountMinor == this.amountMinor &&
          other.reason == this.reason &&
          other.approvedByUserId == this.approvedByUserId &&
          other.approvedAt == this.approvedAt &&
          other.createdAt == this.createdAt);
}

class SaleDiscountsCompanion extends UpdateCompanion<SaleDiscountsData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> saleId;
  final Value<String?> saleItemId;
  final Value<String> discountScope;
  final Value<String> discountType;
  final Value<int> amountMinor;
  final Value<String> reason;
  final Value<String?> approvedByUserId;
  final Value<DateTime?> approvedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SaleDiscountsCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.saleId = const Value.absent(),
    this.saleItemId = const Value.absent(),
    this.discountScope = const Value.absent(),
    this.discountType = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.reason = const Value.absent(),
    this.approvedByUserId = const Value.absent(),
    this.approvedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SaleDiscountsCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String saleId,
    this.saleItemId = const Value.absent(),
    required String discountScope,
    this.discountType = const Value.absent(),
    required int amountMinor,
    required String reason,
    this.approvedByUserId = const Value.absent(),
    this.approvedAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       saleId = Value(saleId),
       discountScope = Value(discountScope),
       amountMinor = Value(amountMinor),
       reason = Value(reason),
       createdAt = Value(createdAt);
  static Insertable<SaleDiscountsData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? saleId,
    Expression<String>? saleItemId,
    Expression<String>? discountScope,
    Expression<String>? discountType,
    Expression<int>? amountMinor,
    Expression<String>? reason,
    Expression<String>? approvedByUserId,
    Expression<DateTime>? approvedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (saleId != null) 'sale_id': saleId,
      if (saleItemId != null) 'sale_item_id': saleItemId,
      if (discountScope != null) 'discount_scope': discountScope,
      if (discountType != null) 'discount_type': discountType,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (reason != null) 'reason': reason,
      if (approvedByUserId != null) 'approved_by_user_id': approvedByUserId,
      if (approvedAt != null) 'approved_at': approvedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SaleDiscountsCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? saleId,
    Value<String?>? saleItemId,
    Value<String>? discountScope,
    Value<String>? discountType,
    Value<int>? amountMinor,
    Value<String>? reason,
    Value<String?>? approvedByUserId,
    Value<DateTime?>? approvedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SaleDiscountsCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      saleId: saleId ?? this.saleId,
      saleItemId: saleItemId ?? this.saleItemId,
      discountScope: discountScope ?? this.discountScope,
      discountType: discountType ?? this.discountType,
      amountMinor: amountMinor ?? this.amountMinor,
      reason: reason ?? this.reason,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedAt: approvedAt ?? this.approvedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (saleItemId.present) {
      map['sale_item_id'] = Variable<String>(saleItemId.value);
    }
    if (discountScope.present) {
      map['discount_scope'] = Variable<String>(discountScope.value);
    }
    if (discountType.present) {
      map['discount_type'] = Variable<String>(discountType.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (approvedByUserId.present) {
      map['approved_by_user_id'] = Variable<String>(approvedByUserId.value);
    }
    if (approvedAt.present) {
      map['approved_at'] = Variable<DateTime>(approvedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SaleDiscountsCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('saleId: $saleId, ')
          ..write('saleItemId: $saleItemId, ')
          ..write('discountScope: $discountScope, ')
          ..write('discountType: $discountType, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('reason: $reason, ')
          ..write('approvedByUserId: $approvedByUserId, ')
          ..write('approvedAt: $approvedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ReceiptSequences extends Table
    with TableInfo<ReceiptSequences, ReceiptSequencesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ReceiptSequences(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
    'branch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES branches (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<String> registerId = GeneratedColumn<String>(
    'register_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES registers (id) ON DELETE RESTRICT',
    ),
  );
  late final GeneratedColumn<int> nextSequence = GeneratedColumn<int>(
    'next_sequence',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('next_sequence > 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('1'),
  );
  late final GeneratedColumn<DateTime> lastIssuedAt = GeneratedColumn<DateTime>(
    'last_issued_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    check: () => const i2.CustomExpression<bool>('version >= 0'),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    organizationId,
    branchId,
    registerId,
    nextSequence,
    lastIssuedAt,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipt_sequences';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {organizationId, branchId, registerId},
  ];
  @override
  ReceiptSequencesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptSequencesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      )!,
      branchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_id'],
      )!,
      registerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}register_id'],
      )!,
      nextSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_sequence'],
      )!,
      lastIssuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_issued_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  ReceiptSequences createAlias(String alias) {
    return ReceiptSequences(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY (branch_id, organization_id) REFERENCES branches (id, organization_id) ON DELETE RESTRICT',
    'FOREIGN KEY (register_id, organization_id, branch_id) REFERENCES registers (id, organization_id, branch_id) ON DELETE RESTRICT',
  ];
}

class ReceiptSequencesData extends DataClass
    implements Insertable<ReceiptSequencesData> {
  final String id;
  final String organizationId;
  final String branchId;
  final String registerId;
  final int nextSequence;
  final DateTime? lastIssuedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ReceiptSequencesData({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.registerId,
    required this.nextSequence,
    this.lastIssuedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['organization_id'] = Variable<String>(organizationId);
    map['branch_id'] = Variable<String>(branchId);
    map['register_id'] = Variable<String>(registerId);
    map['next_sequence'] = Variable<int>(nextSequence);
    if (!nullToAbsent || lastIssuedAt != null) {
      map['last_issued_at'] = Variable<DateTime>(lastIssuedAt);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReceiptSequencesCompanion toCompanion(bool nullToAbsent) {
    return ReceiptSequencesCompanion(
      id: Value(id),
      organizationId: Value(organizationId),
      branchId: Value(branchId),
      registerId: Value(registerId),
      nextSequence: Value(nextSequence),
      lastIssuedAt: lastIssuedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastIssuedAt),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReceiptSequencesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptSequencesData(
      id: serializer.fromJson<String>(json['id']),
      organizationId: serializer.fromJson<String>(json['organizationId']),
      branchId: serializer.fromJson<String>(json['branchId']),
      registerId: serializer.fromJson<String>(json['registerId']),
      nextSequence: serializer.fromJson<int>(json['nextSequence']),
      lastIssuedAt: serializer.fromJson<DateTime?>(json['lastIssuedAt']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'organizationId': serializer.toJson<String>(organizationId),
      'branchId': serializer.toJson<String>(branchId),
      'registerId': serializer.toJson<String>(registerId),
      'nextSequence': serializer.toJson<int>(nextSequence),
      'lastIssuedAt': serializer.toJson<DateTime?>(lastIssuedAt),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReceiptSequencesData copyWith({
    String? id,
    String? organizationId,
    String? branchId,
    String? registerId,
    int? nextSequence,
    Value<DateTime?> lastIssuedAt = const Value.absent(),
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ReceiptSequencesData(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    branchId: branchId ?? this.branchId,
    registerId: registerId ?? this.registerId,
    nextSequence: nextSequence ?? this.nextSequence,
    lastIssuedAt: lastIssuedAt.present ? lastIssuedAt.value : this.lastIssuedAt,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReceiptSequencesData copyWithCompanion(ReceiptSequencesCompanion data) {
    return ReceiptSequencesData(
      id: data.id.present ? data.id.value : this.id,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      registerId: data.registerId.present
          ? data.registerId.value
          : this.registerId,
      nextSequence: data.nextSequence.present
          ? data.nextSequence.value
          : this.nextSequence,
      lastIssuedAt: data.lastIssuedAt.present
          ? data.lastIssuedAt.value
          : this.lastIssuedAt,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptSequencesData(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('registerId: $registerId, ')
          ..write('nextSequence: $nextSequence, ')
          ..write('lastIssuedAt: $lastIssuedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    organizationId,
    branchId,
    registerId,
    nextSequence,
    lastIssuedAt,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptSequencesData &&
          other.id == this.id &&
          other.organizationId == this.organizationId &&
          other.branchId == this.branchId &&
          other.registerId == this.registerId &&
          other.nextSequence == this.nextSequence &&
          other.lastIssuedAt == this.lastIssuedAt &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ReceiptSequencesCompanion extends UpdateCompanion<ReceiptSequencesData> {
  final Value<String> id;
  final Value<String> organizationId;
  final Value<String> branchId;
  final Value<String> registerId;
  final Value<int> nextSequence;
  final Value<DateTime?> lastIssuedAt;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReceiptSequencesCompanion({
    this.id = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.registerId = const Value.absent(),
    this.nextSequence = const Value.absent(),
    this.lastIssuedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptSequencesCompanion.insert({
    required String id,
    required String organizationId,
    required String branchId,
    required String registerId,
    this.nextSequence = const Value.absent(),
    this.lastIssuedAt = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       organizationId = Value(organizationId),
       branchId = Value(branchId),
       registerId = Value(registerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ReceiptSequencesData> custom({
    Expression<String>? id,
    Expression<String>? organizationId,
    Expression<String>? branchId,
    Expression<String>? registerId,
    Expression<int>? nextSequence,
    Expression<DateTime>? lastIssuedAt,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (organizationId != null) 'organization_id': organizationId,
      if (branchId != null) 'branch_id': branchId,
      if (registerId != null) 'register_id': registerId,
      if (nextSequence != null) 'next_sequence': nextSequence,
      if (lastIssuedAt != null) 'last_issued_at': lastIssuedAt,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptSequencesCompanion copyWith({
    Value<String>? id,
    Value<String>? organizationId,
    Value<String>? branchId,
    Value<String>? registerId,
    Value<int>? nextSequence,
    Value<DateTime?>? lastIssuedAt,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReceiptSequencesCompanion(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      branchId: branchId ?? this.branchId,
      registerId: registerId ?? this.registerId,
      nextSequence: nextSequence ?? this.nextSequence,
      lastIssuedAt: lastIssuedAt ?? this.lastIssuedAt,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (registerId.present) {
      map['register_id'] = Variable<String>(registerId.value);
    }
    if (nextSequence.present) {
      map['next_sequence'] = Variable<int>(nextSequence.value);
    }
    if (lastIssuedAt.present) {
      map['last_issued_at'] = Variable<DateTime>(lastIssuedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptSequencesCompanion(')
          ..write('id: $id, ')
          ..write('organizationId: $organizationId, ')
          ..write('branchId: $branchId, ')
          ..write('registerId: $registerId, ')
          ..write('nextSequence: $nextSequence, ')
          ..write('lastIssuedAt: $lastIssuedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DatabaseAtV7 extends GeneratedDatabase {
  DatabaseAtV7(QueryExecutor e) : super(e);
  late final LocalMetadata localMetadata = LocalMetadata(this);
  late final SyncOutbox syncOutbox = SyncOutbox(this);
  late final SyncCursors syncCursors = SyncCursors(this);
  late final SyncConflicts syncConflicts = SyncConflicts(this);
  late final SyncEntityVersions syncEntityVersions = SyncEntityVersions(this);
  late final LocalAuditLogs localAuditLogs = LocalAuditLogs(this);
  late final Organizations organizations = Organizations(this);
  late final Branches branches = Branches(this);
  late final AppUsers appUsers = AppUsers(this);
  late final Roles roles = Roles(this);
  late final Permissions permissions = Permissions(this);
  late final RolePermissions rolePermissions = RolePermissions(this);
  late final UserRoleAssignments userRoleAssignments = UserRoleAssignments(
    this,
  );
  late final Categories categories = Categories(this);
  late final Units units = Units(this);
  late final TaxCategories taxCategories = TaxCategories(this);
  late final Products products = Products(this);
  late final ProductBarcodes productBarcodes = ProductBarcodes(this);
  late final ProductPrices productPrices = ProductPrices(this);
  late final ProductImages productImages = ProductImages(this);
  late final StockLocations stockLocations = StockLocations(this);
  late final InventoryTransactions inventoryTransactions =
      InventoryTransactions(this);
  late final InventoryLedgerEntries inventoryLedgerEntries =
      InventoryLedgerEntries(this);
  late final InventoryBalances inventoryBalances = InventoryBalances(this);
  late final StockCounts stockCounts = StockCounts(this);
  late final StockCountItems stockCountItems = StockCountItems(this);
  late final Registers registers = Registers(this);
  late final Shifts shifts = Shifts(this);
  late final CashMovements cashMovements = CashMovements(this);
  late final ShiftCounts shiftCounts = ShiftCounts(this);
  late final Sales sales = Sales(this);
  late final SaleItems saleItems = SaleItems(this);
  late final Payments payments = Payments(this);
  late final SaleDiscounts saleDiscounts = SaleDiscounts(this);
  late final ReceiptSequences receiptSequences = ReceiptSequences(this);
  late final Index categoriesSearchIdx = Index(
    'categories_search_idx',
    'CREATE INDEX categories_search_idx ON categories (organization_id, normalized_name)',
  );
  late final Index productsNameSearchIdx = Index(
    'products_name_search_idx',
    'CREATE INDEX products_name_search_idx ON products (organization_id, normalized_name)',
  );
  late final Index productsSkuSearchIdx = Index(
    'products_sku_search_idx',
    'CREATE INDEX products_sku_search_idx ON products (organization_id, normalized_sku)',
  );
  late final Index productBarcodesSearchIdx = Index(
    'product_barcodes_search_idx',
    'CREATE INDEX product_barcodes_search_idx ON product_barcodes (organization_id, normalized_barcode)',
  );
  late final Index stockLocationsBranchIdx = Index(
    'stock_locations_branch_idx',
    'CREATE INDEX stock_locations_branch_idx ON stock_locations (organization_id, branch_id, is_active)',
  );
  late final Index inventoryTransactionsHistoryIdx = Index(
    'inventory_transactions_history_idx',
    'CREATE INDEX inventory_transactions_history_idx ON inventory_transactions (organization_id, branch_id, occurred_at)',
  );
  late final Index inventoryLedgerProductHistoryIdx = Index(
    'inventory_ledger_product_history_idx',
    'CREATE INDEX inventory_ledger_product_history_idx ON inventory_ledger_entries (organization_id, branch_id, product_id, occurred_at)',
  );
  late final Index inventoryBalancesLowStockIdx = Index(
    'inventory_balances_low_stock_idx',
    'CREATE INDEX inventory_balances_low_stock_idx ON inventory_balances (organization_id, branch_id, stock_location_id, on_hand_milli)',
  );
  late final Index stockCountsStatusIdx = Index(
    'stock_counts_status_idx',
    'CREATE INDEX stock_counts_status_idx ON stock_counts (organization_id, branch_id, stock_location_id, status)',
  );
  late final Index registersBranchIdx = Index(
    'registers_branch_idx',
    'CREATE INDEX registers_branch_idx ON registers (organization_id, branch_id, is_active)',
  );
  late final Index shiftsActiveIdx = Index(
    'shifts_active_idx',
    'CREATE INDEX shifts_active_idx ON shifts (organization_id, branch_id, status, opened_by_user_id)',
  );
  late final Index cashMovementsShiftIdx = Index(
    'cash_movements_shift_idx',
    'CREATE INDEX cash_movements_shift_idx ON cash_movements (organization_id, branch_id, shift_id, occurred_at)',
  );
  late final Index salesHistoryIdx = Index(
    'sales_history_idx',
    'CREATE INDEX sales_history_idx ON sales (organization_id, branch_id, completed_at)',
  );
  late final Index paymentsShiftIdx = Index(
    'payments_shift_idx',
    'CREATE INDEX payments_shift_idx ON payments (organization_id, branch_id, shift_id, created_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localMetadata,
    syncOutbox,
    syncCursors,
    syncConflicts,
    syncEntityVersions,
    localAuditLogs,
    organizations,
    branches,
    appUsers,
    roles,
    permissions,
    rolePermissions,
    userRoleAssignments,
    categories,
    units,
    taxCategories,
    products,
    productBarcodes,
    productPrices,
    productImages,
    stockLocations,
    inventoryTransactions,
    inventoryLedgerEntries,
    inventoryBalances,
    stockCounts,
    stockCountItems,
    registers,
    shifts,
    cashMovements,
    shiftCounts,
    sales,
    saleItems,
    payments,
    saleDiscounts,
    receiptSequences,
    categoriesSearchIdx,
    productsNameSearchIdx,
    productsSkuSearchIdx,
    productBarcodesSearchIdx,
    stockLocationsBranchIdx,
    inventoryTransactionsHistoryIdx,
    inventoryLedgerProductHistoryIdx,
    inventoryBalancesLowStockIdx,
    stockCountsStatusIdx,
    registersBranchIdx,
    shiftsActiveIdx,
    cashMovementsShiftIdx,
    salesHistoryIdx,
    paymentsShiftIdx,
  ];
  @override
  int get schemaVersion => 7;
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}
