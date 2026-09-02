import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/report_filter_options.dart';
import '../../domain/repositories/reports_repository.dart';
import '../data_sources/reports_local_data_source.dart';

class DriftReportsRepository implements ReportsRepository {
  const DriftReportsRepository(this._localDataSource);

  final ReportsLocalDataSource _localDataSource;

  @override
  Future<Result<ReportDataset, Failure>> loadReport({
    required BusinessContext context,
    required ReportType type,
    required ReportFilter filter,
  }) async {
    if (filter.branchId != context.branchId) {
      return const Result.failure(
        AuthorizationFailure('The report branch does not match its context.'),
      );
    }
    try {
      return Result.success(
        await _localDataSource.loadReport(
          organizationId: context.organizationId,
          type: type,
          filter: filter,
        ),
      );
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          'The local report could not be generated.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<ReportFilterOptions, Failure>> loadFilterOptions({
    required String organizationId,
  }) async {
    try {
      return Result.success(
        await _localDataSource.loadFilterOptions(organizationId),
      );
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          'Report filters could not be loaded.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
