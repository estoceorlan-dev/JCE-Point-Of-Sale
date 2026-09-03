import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../entities/audit_log_filter.dart';
import '../repositories/logs_repository.dart';

class WatchAuditTrailUseCase {
  const WatchAuditTrailUseCase(this._repository);

  final LogsRepository _repository;

  Stream<Result<List<AuditLogEntry>, Failure>> call({
    required AuthSession? session,
    required AuditLogFilter filter,
  }) {
    if (session == null) {
      return Stream.value(
        const Result.failure(
          AuthorizationFailure('Authentication is required.'),
        ),
      );
    }
    final branchId = filter.branchId ?? session.activeBranchId;
    final branch = session.activeOrganization.branchById(branchId);
    if (branch == null ||
        !session.activeOrganization
            .permissionsFor(branchId)
            .contains(AppPermission.viewAuditLogs)) {
      return Stream.value(
        const Result.failure(
          AuthorizationFailure(
            'Audit logs are unavailable for the selected branch.',
          ),
        ),
      );
    }
    if (filter.page < 1 ||
        filter.pageSize < 1 ||
        filter.pageSize > 200 ||
        (filter.from != null &&
            filter.to != null &&
            !filter.from!.isBefore(filter.to!))) {
      return Stream.value(
        const Result.failure(ValidationFailure('Audit filters are invalid.')),
      );
    }
    return _repository
        .watchAuditTrail(
          context: BusinessContext(
            organizationId: session.activeOrganizationId,
            branchId: branchId,
            actorUserId: session.activeOrganization.appUserId,
          ),
          filter: filter.copyWith(branchId: branchId),
        )
        .map(Result.success);
  }
}
