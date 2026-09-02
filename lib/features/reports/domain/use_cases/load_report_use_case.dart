import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../entities/report_dataset.dart';
import '../entities/report_filter.dart';
import '../repositories/reports_repository.dart';

class LoadReportUseCase {
  const LoadReportUseCase(this._repository);

  final ReportsRepository _repository;

  Future<Result<ReportDataset, Failure>> call({
    required AuthSession? session,
    required ReportType type,
    required ReportFilter filter,
  }) {
    final failure = _validate(session, filter);
    if (failure != null) return Future.value(Result.failure(failure));
    return _repository.loadReport(
      context: BusinessContext(
        organizationId: session!.activeOrganizationId,
        branchId: filter.branchId,
        actorUserId: session.activeOrganization.appUserId,
      ),
      type: type,
      filter: filter,
    );
  }

  Failure? _validate(AuthSession? session, ReportFilter filter) {
    if (session == null) {
      return const AuthorizationFailure('Authentication is required.');
    }
    final branch = session.activeOrganization.branchById(filter.branchId);
    if (branch == null ||
        !session.activeOrganization
            .permissionsFor(filter.branchId)
            .contains(AppPermission.viewReports)) {
      return const AuthorizationFailure(
        'Reports are unavailable for the selected branch.',
      );
    }
    if (!filter.fromUtc.isBefore(filter.toUtcExclusive)) {
      return const ValidationFailure('The report date range is invalid.');
    }
    if (filter.page < 1 || filter.pageSize < 1 || filter.pageSize > 200) {
      return const ValidationFailure('The report page request is invalid.');
    }
    return null;
  }
}
