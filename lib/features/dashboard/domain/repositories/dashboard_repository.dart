import '../../../../shared/models/business_context.dart';
import '../entities/dashboard_summary.dart';

abstract interface class DashboardRepository {
  Stream<DashboardSummary> watchSummary({
    required BusinessContext context,
    required DateTime fromUtc,
    required DateTime toUtcExclusive,
  });
}
