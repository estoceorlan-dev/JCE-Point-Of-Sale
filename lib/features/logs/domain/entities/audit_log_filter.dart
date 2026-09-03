import '../../../../shared/models/audit_log_entry.dart';

class AuditLogFilter {
  const AuditLogFilter({
    this.branchId,
    this.actorUserId,
    this.actionType,
    this.entityName,
    this.search = '',
    this.from,
    this.to,
    this.page = 1,
    this.pageSize = 50,
  });

  final String? branchId;
  final String? actorUserId;
  final AuditActionType? actionType;
  final String? entityName;
  final String search;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int pageSize;

  AuditLogFilter copyWith({
    String? branchId,
    String? actorUserId,
    AuditActionType? actionType,
    String? entityName,
    String? search,
    DateTime? from,
    DateTime? to,
    int? page,
    int? pageSize,
    bool clearActionType = false,
    bool clearEntityName = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) => AuditLogFilter(
    branchId: branchId ?? this.branchId,
    actorUserId: actorUserId ?? this.actorUserId,
    actionType: clearActionType ? null : actionType ?? this.actionType,
    entityName: clearEntityName ? null : entityName ?? this.entityName,
    search: search ?? this.search,
    from: clearFrom ? null : from ?? this.from,
    to: clearTo ? null : to ?? this.to,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
  );
}
