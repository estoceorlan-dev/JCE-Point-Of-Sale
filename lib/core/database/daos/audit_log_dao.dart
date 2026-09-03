import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../shared/models/audit_log_entry.dart' as model;
import '../../security/audit_metadata_sanitizer.dart';
import '../app_database.dart';
import '../tables/local_audit_logs_table.dart';

part 'audit_log_dao.g.dart';

@DriftAccessor(tables: [LocalAuditLogs])
class AuditLogDao extends DatabaseAccessor<AppDatabase>
    with _$AuditLogDaoMixin {
  AuditLogDao(super.attachedDatabase);

  Future<void> append(model.AuditLogEntry entry) async {
    final deviceId = entry.deviceId ?? await _localDeviceId();
    await into(localAuditLogs).insert(
      LocalAuditLogsCompanion.insert(
        id: entry.id,
        operationId: Value(entry.operationId),
        organizationId: Value(entry.organizationId),
        actorUserId: entry.actorUserId,
        branchId: Value(entry.branchId),
        deviceId: Value(deviceId),
        actionType: entry.actionType.name,
        auditedEntityName: entry.entityName,
        entityId: entry.entityId,
        metadataJson: Value(jsonEncode(sanitizeAuditMetadata(entry.metadata))),
        createdAt: entry.createdAt.toUtc(),
      ),
    );
  }

  Stream<List<model.AuditLogEntry>> watchEntries({
    String? organizationId,
    String? branchId,
    String? actorUserId,
    model.AuditActionType? actionType,
    String? entityName,
    String? search,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int offset = 0,
  }) {
    final query = select(localAuditLogs);
    if (organizationId != null) {
      query.where((row) => row.organizationId.equals(organizationId));
    }
    if (branchId != null) {
      query.where(
        (row) => row.branchId.isNull() | row.branchId.equals(branchId),
      );
    }
    if (actorUserId != null && actorUserId.trim().isNotEmpty) {
      query.where((row) => row.actorUserId.equals(actorUserId.trim()));
    }
    if (actionType != null) {
      query.where((row) => row.actionType.equals(actionType.name));
    }
    if (entityName != null && entityName.trim().isNotEmpty) {
      query.where((row) => row.auditedEntityName.equals(entityName.trim()));
    }
    if (from != null) {
      query.where((row) => row.createdAt.isBiggerOrEqualValue(from.toUtc()));
    }
    if (to != null) {
      query.where((row) => row.createdAt.isSmallerThanValue(to.toUtc()));
    }
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim();
      query.where(
        (row) =>
            row.operationId.contains(term) |
            row.entityId.contains(term) |
            row.auditedEntityName.contains(term) |
            row.actorUserId.contains(term),
      );
    }
    query
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
      ..limit(limit, offset: offset);

    return query.watch().map(
      (rows) => rows.map(_toModel).toList(growable: false),
    );
  }

  Future<String?> _localDeviceId() async {
    final row = await customSelect(
      'SELECT value FROM local_metadata WHERE `key` = ?',
      variables: [const Variable<String>('device.id')],
    ).getSingleOrNull();
    return row?.read<String>('value');
  }

  model.AuditLogEntry _toModel(LocalAuditLog row) {
    return model.AuditLogEntry(
      id: row.id,
      operationId: row.operationId,
      organizationId: row.organizationId,
      actorUserId: row.actorUserId,
      branchId: row.branchId,
      deviceId: row.deviceId,
      actionType: model.AuditActionType.values.byName(row.actionType),
      entityName: row.auditedEntityName,
      entityId: row.entityId,
      metadata: (jsonDecode(row.metadataJson) as Map<String, dynamic>)
          .cast<String, Object?>(),
      createdAt: row.createdAt.toUtc(),
    );
  }
}
