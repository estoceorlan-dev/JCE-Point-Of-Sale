import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/branch_business_day.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/data_sources/reports_local_data_source.dart';
import '../../data/repositories/drift_reports_repository.dart';
import '../../data/services/csv_report_exporter.dart';
import '../../data/services/printable_report_builder.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/report_filter_options.dart';
import '../../domain/repositories/reports_repository.dart';
import '../../domain/services/report_exporter.dart';
import '../../domain/use_cases/load_report_filter_options_use_case.dart';
import '../../domain/use_cases/load_report_use_case.dart';

final reportsBusinessDayProvider = Provider<BranchBusinessDay>(
  (ref) => BranchBusinessDay(),
);

final reportsLocalDataSourceProvider = Provider<ReportsLocalDataSource>(
  (ref) => ReportsLocalDataSource(
    ref.watch(appDatabaseProvider),
    ref.watch(reportsBusinessDayProvider),
  ),
);

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => DriftReportsRepository(ref.watch(reportsLocalDataSourceProvider)),
);

final loadReportUseCaseProvider = Provider<LoadReportUseCase>(
  (ref) => LoadReportUseCase(ref.watch(reportsRepositoryProvider)),
);

final loadReportFilterOptionsUseCaseProvider =
    Provider<LoadReportFilterOptionsUseCase>(
      (ref) =>
          LoadReportFilterOptionsUseCase(ref.watch(reportsRepositoryProvider)),
    );

final reportTypeProvider = StateProvider<ReportType>(
  (ref) => ReportType.dailyBranchSales,
);

final reportFilterStateProvider = StateProvider<ReportFilterState>((ref) {
  final session = ref.watch(authControllerProvider).asData?.value;
  final clock = ref.watch(appClockProvider);
  final businessDay = ref.watch(reportsBusinessDayProvider);
  final now = clock.nowUtc();
  final today = session == null
      ? DateTime(now.year, now.month, now.day)
      : businessDay.localDate(now, session.activeBranch.branch.timezone);
  return ReportFilterState(
    branchId: session?.activeBranchId ?? '',
    fromDate: today.subtract(const Duration(days: 29)),
    toDate: today,
  );
});

final reportFilterOptionsProvider =
    FutureProvider<Result<ReportFilterOptions, Failure>>((ref) {
      final session = ref.watch(authControllerProvider).asData?.value;
      return ref.watch(loadReportFilterOptionsUseCaseProvider).call(session);
    });

final reportDatasetProvider = FutureProvider<Result<ReportDataset, Failure>>((
  ref,
) {
  final session = ref.watch(authControllerProvider).asData?.value;
  final state = ref.watch(reportFilterStateProvider);
  final branch = session?.activeOrganization.branchById(state.branchId);
  if (session == null || branch == null) {
    return Future.value(
      const Result.failure(
        _ReportContextFailure('Select an accessible report branch.'),
      ),
    );
  }
  final range = ref
      .watch(reportsBusinessDayProvider)
      .range(
        fromDate: state.fromDate,
        toDate: state.toDate,
        timezoneName: branch.branch.timezone,
      );
  return ref
      .watch(loadReportUseCaseProvider)
      .call(
        session: session,
        type: ref.watch(reportTypeProvider),
        filter: ReportFilter(
          branchId: state.branchId,
          fromUtc: range.start,
          toUtcExclusive: range.endExclusive,
          productId: state.productId,
          categoryId: state.categoryId,
          userId: state.userId,
          paymentMethod: state.paymentMethod,
          page: state.page,
          pageSize: state.pageSize,
        ),
      );
});

final csvReportExporterProvider = Provider<ReportExporter<String>>(
  (ref) => const CsvReportExporter(),
);

final printableReportBuilderProvider =
    Provider<ReportExporter<PrintableReportDocument>>(
      (ref) => const PrintableReportBuilder(),
    );

class ReportFilterState {
  const ReportFilterState({
    required this.branchId,
    required this.fromDate,
    required this.toDate,
    this.productId,
    this.categoryId,
    this.userId,
    this.paymentMethod,
    this.page = 1,
    this.pageSize = 25,
  });

  final String branchId;
  final DateTime fromDate;
  final DateTime toDate;
  final String? productId;
  final String? categoryId;
  final String? userId;
  final String? paymentMethod;
  final int page;
  final int pageSize;

  ReportFilterState copyWith({
    String? branchId,
    DateTime? fromDate,
    DateTime? toDate,
    Object? productId = _unset,
    Object? categoryId = _unset,
    Object? userId = _unset,
    Object? paymentMethod = _unset,
    int? page,
  }) {
    return ReportFilterState(
      branchId: branchId ?? this.branchId,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      productId: identical(productId, _unset)
          ? this.productId
          : productId as String?,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as String?,
      userId: identical(userId, _unset) ? this.userId : userId as String?,
      paymentMethod: identical(paymentMethod, _unset)
          ? this.paymentMethod
          : paymentMethod as String?,
      page: page ?? this.page,
      pageSize: pageSize,
    );
  }

  ReportFilter toFilter({required DateTime start, required DateTime end}) {
    return ReportFilter(
      branchId: branchId,
      fromUtc: start,
      toUtcExclusive: end,
      productId: productId,
      categoryId: categoryId,
      userId: userId,
      paymentMethod: paymentMethod,
      page: page,
      pageSize: pageSize,
    );
  }
}

class _ReportContextFailure extends Failure {
  const _ReportContextFailure(super.message);

  @override
  FailureType get type => FailureType.authorization;
}

const _unset = Object();

List<String> permittedReportBranchIds(WidgetRef ref) {
  final session = ref.watch(authControllerProvider).asData?.value;
  if (session == null) return const [];
  return [
    for (final access in session.activeOrganization.branches)
      if (session.activeOrganization
          .permissionsFor(access.branch.id)
          .contains(AppPermission.viewReports))
        access.branch.id,
  ];
}
