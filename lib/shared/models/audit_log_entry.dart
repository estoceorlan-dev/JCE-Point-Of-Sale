enum AuditActionType {
  create,
  update,
  delete,
  login,
  logout,
  loginFailed,
  branchSwitch,
  roleChange,
  settingChange,
  sale,
  transfer,
  sync,
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorUserId,
    required this.actionType,
    required this.entityName,
    required this.entityId,
    required this.createdAt,
    this.operationId,
    this.organizationId,
    this.branchId,
    this.deviceId,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String? operationId;
  final String? organizationId;
  final String actorUserId;
  final String? branchId;
  final String? deviceId;
  final AuditActionType actionType;
  final String entityName;
  final String entityId;
  final DateTime createdAt;
  final Map<String, Object?> metadata;
}
