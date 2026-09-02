import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/branch_business_day.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/data_sources/dashboard_local_data_source.dart';
import '../../data/repositories/drift_dashboard_repository.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/use_cases/watch_dashboard_summary_use_case.dart';

final branchBusinessDayProvider = Provider<BranchBusinessDay>(
  (ref) => BranchBusinessDay(),
);

final dashboardLocalDataSourceProvider = Provider<DashboardLocalDataSource>(
  (ref) => DashboardLocalDataSource(ref.watch(appDatabaseProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) =>
      DriftDashboardRepository(ref.watch(dashboardLocalDataSourceProvider)),
);

final watchDashboardSummaryUseCaseProvider =
    Provider<WatchDashboardSummaryUseCase>(
      (ref) =>
          WatchDashboardSummaryUseCase(ref.watch(dashboardRepositoryProvider)),
    );

final dashboardSummaryProvider = StreamProvider<DashboardSummary>((ref) {
  final session = ref.watch(authControllerProvider).asData?.value;
  if (session == null) return Stream.value(const DashboardSummary.empty());
  final businessDay = ref.watch(branchBusinessDayProvider);
  final today = businessDay.localDate(
    ref.watch(appClockProvider).nowUtc(),
    session.activeBranch.branch.timezone,
  );
  final range = businessDay.range(
    fromDate: today,
    toDate: today,
    timezoneName: session.activeBranch.branch.timezone,
  );
  final result = ref
      .watch(watchDashboardSummaryUseCaseProvider)
      .call(
        session: session,
        fromUtc: range.start,
        toUtcExclusive: range.endExclusive,
      );
  return result.fold(
    onSuccess: (stream) => stream,
    onFailure: (failure) => Stream.error(failure),
  );
});
