import '../../../../core/database/daos/audit_log_dao.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/audit_log_filter.dart';
import '../../domain/repositories/logs_repository.dart';

class DriftLogsRepository implements LogsRepository {
  const DriftLogsRepository(this._auditLogDao);

  final AuditLogDao _auditLogDao;

  @override
  Stream<List<AuditLogEntry>> watchAuditTrail({
    required BusinessContext context,
    AuditLogFilter filter = const AuditLogFilter(),
  }) {
    return _auditLogDao.watchEntries(
      organizationId: context.organizationId,
      branchId: filter.branchId ?? context.branchId,
      actorUserId: filter.actorUserId,
      actionType: filter.actionType,
      entityName: filter.entityName,
      search: filter.search,
      from: filter.from,
      to: filter.to,
      limit: filter.pageSize,
      offset: (filter.page - 1) * filter.pageSize,
    );
  }
}
