import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/audit_log_filter.dart';

abstract interface class LogsRepository {
  Stream<List<AuditLogEntry>> watchAuditTrail({
    required BusinessContext context,
    AuditLogFilter filter = const AuditLogFilter(),
  });
}
