import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/drift_logs_repository.dart';
import '../../domain/entities/audit_log_filter.dart';
import '../../domain/repositories/logs_repository.dart';
import '../../domain/use_cases/watch_audit_trail_use_case.dart';

final logsRepositoryProvider = Provider<LogsRepository>(
  (ref) => DriftLogsRepository(ref.watch(auditLogDaoProvider)),
);

final watchAuditTrailUseCaseProvider = Provider<WatchAuditTrailUseCase>(
  (ref) => WatchAuditTrailUseCase(ref.watch(logsRepositoryProvider)),
);

final auditLogFilterProvider = StateProvider<AuditLogFilter>((ref) {
  final session = ref.watch(authControllerProvider).asData?.value;
  return AuditLogFilter(branchId: session?.activeBranchId);
});

final auditTrailProvider = StreamProvider<Result<List<AuditLogEntry>, Failure>>(
  (ref) {
    return ref
        .watch(watchAuditTrailUseCaseProvider)
        .call(
          session: ref.watch(authControllerProvider).asData?.value,
          filter: ref.watch(auditLogFilterProvider),
        );
  },
);
