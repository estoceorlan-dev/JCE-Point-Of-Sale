import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/report_dataset.dart';
import '../entities/report_filter.dart';
import '../entities/report_filter_options.dart';

abstract interface class ReportsRepository {
  Future<Result<ReportDataset, Failure>> loadReport({
    required BusinessContext context,
    required ReportType type,
    required ReportFilter filter,
  });

  Future<Result<ReportFilterOptions, Failure>> loadFilterOptions({
    required String organizationId,
  });
}
