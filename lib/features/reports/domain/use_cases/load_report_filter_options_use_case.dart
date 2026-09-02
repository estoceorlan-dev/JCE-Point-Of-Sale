import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../entities/report_filter_options.dart';
import '../repositories/reports_repository.dart';

class LoadReportFilterOptionsUseCase {
  const LoadReportFilterOptionsUseCase(this._repository);

  final ReportsRepository _repository;

  Future<Result<ReportFilterOptions, Failure>> call(AuthSession? session) {
    if (session == null ||
        !session.activeOrganization.branches.any(
          (access) => session.activeOrganization
              .permissionsFor(access.branch.id)
              .contains(AppPermission.viewReports),
        )) {
      return Future.value(
        const Result.failure(
          AuthorizationFailure('Report access is required.'),
        ),
      );
    }
    return _repository.loadFilterOptions(
      organizationId: session.activeOrganizationId,
    );
  }
}
