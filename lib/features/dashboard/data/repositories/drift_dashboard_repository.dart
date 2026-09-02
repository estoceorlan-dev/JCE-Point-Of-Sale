import '../../../../shared/models/business_context.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../data_sources/dashboard_local_data_source.dart';

class DriftDashboardRepository implements DashboardRepository {
  const DriftDashboardRepository(this._localDataSource);

  final DashboardLocalDataSource _localDataSource;

  @override
  Stream<DashboardSummary> watchSummary({
    required BusinessContext context,
    required DateTime fromUtc,
    required DateTime toUtcExclusive,
  }) => _localDataSource.watchSummary(
    organizationId: context.organizationId,
    branchId: context.branchId,
    fromUtc: fromUtc,
    toUtcExclusive: toUtcExclusive,
  );
}
