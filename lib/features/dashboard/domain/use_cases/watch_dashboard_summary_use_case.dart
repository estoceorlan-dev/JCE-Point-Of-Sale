import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

class WatchDashboardSummaryUseCase {
  const WatchDashboardSummaryUseCase(this._repository);

  final DashboardRepository _repository;

  Result<Stream<DashboardSummary>, Failure> call({
    required AuthSession? session,
    required DateTime fromUtc,
    required DateTime toUtcExclusive,
  }) {
    if (session == null) {
      return const Result.failure(
        AuthorizationFailure('Authentication is required.'),
      );
    }
    if (!session.can(AppPermission.viewDashboard)) {
      return const Result.failure(
        AuthorizationFailure('Dashboard access is required.'),
      );
    }
    return Result.success(
      _repository.watchSummary(
        context: BusinessContext(
          organizationId: session.activeOrganizationId,
          branchId: session.activeBranchId,
          actorUserId: session.activeOrganization.appUserId,
        ),
        fromUtc: fromUtc,
        toUtcExclusive: toUtcExclusive,
      ),
    );
  }
}
