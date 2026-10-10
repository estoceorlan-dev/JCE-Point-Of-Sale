// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log_dao.dart';

// ignore_for_file: type=lint
mixin _$AuditLogDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalAuditLogsTable get localAuditLogs => attachedDatabase.localAuditLogs;
  AuditLogDaoManager get managers => AuditLogDaoManager(this);
}

class AuditLogDaoManager {
  final _$AuditLogDaoMixin _db;
  AuditLogDaoManager(this._db);
  $$LocalAuditLogsTableTableManager get localAuditLogs =>
      $$LocalAuditLogsTableTableManager(
        _db.attachedDatabase,
        _db.localAuditLogs,
      );
}
