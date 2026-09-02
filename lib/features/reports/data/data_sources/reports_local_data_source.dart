import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/branch_business_day.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/report_filter_options.dart';
import 'inventory_movement_report_query.dart';
import 'inventory_report_queries.dart';
import 'purchasing_report_query.dart';
import 'sales_performance_report_queries.dart';
import 'sales_summary_report_queries.dart';
import 'shift_report_query.dart';
import 'transfer_report_query.dart';

class ReportsLocalDataSource {
  ReportsLocalDataSource(AppDatabase database, BranchBusinessDay businessDay)
    : _database = database,
      _salesSummary = SalesSummaryReportQueries(database, businessDay),
      _salesPerformance = SalesPerformanceReportQueries(database),
      _inventory = InventoryReportQueries(database),
      _inventoryMovement = InventoryMovementReportQuery(database),
      _shifts = ShiftReportQuery(database),
      _transfers = TransferReportQuery(database),
      _purchasing = PurchasingReportQuery(database);

  final AppDatabase _database;
  final SalesSummaryReportQueries _salesSummary;
  final SalesPerformanceReportQueries _salesPerformance;
  final InventoryReportQueries _inventory;
  final InventoryMovementReportQuery _inventoryMovement;
  final ShiftReportQuery _shifts;
  final TransferReportQuery _transfers;
  final PurchasingReportQuery _purchasing;

  Future<ReportDataset> loadReport({
    required String organizationId,
    required ReportType type,
    required ReportFilter filter,
  }) async {
    final branch =
        await (_database.select(_database.branches)..where(
              (row) =>
                  row.id.equals(filter.branchId) &
                  row.organizationId.equals(organizationId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (branch == null) {
      throw StateError('The report branch is not available locally.');
    }
    return switch (type) {
      ReportType.dailyBranchSales => _salesSummary.dailySales(
        organizationId: organizationId,
        timezoneName: branch.timezone,
        filter: filter,
      ),
      ReportType.paymentMethodTotals => _salesSummary.paymentTotals(
        organizationId: organizationId,
        filter: filter,
      ),
      ReportType.cashierPerformance => _salesPerformance.cashierPerformance(
        organizationId: organizationId,
        filter: filter,
      ),
      ReportType.productSales => _salesPerformance.productSales(
        organizationId: organizationId,
        filter: filter,
      ),
      ReportType.grossProfitEstimate => _salesPerformance.grossProfit(
        organizationId: organizationId,
        filter: filter,
      ),
      ReportType.inventoryValuation => _inventory.valuation(
        organizationId: organizationId,
        filter: filter,
      ),
      ReportType.lowStock => _inventory.lowStock(
        organizationId: organizationId,
        filter: filter,
      ),
      ReportType.inventoryMovement => _inventoryMovement.load(
        organizationId: organizationId,
        filter: filter,
      ),
      ReportType.shiftReconciliation => _shifts.load(
        organizationId: organizationId,
        filter: filter,
      ),
      ReportType.transferPerformance => _transfers.load(
        organizationId: organizationId,
        filter: filter,
      ),
      ReportType.purchaseReceivingPerformance => _purchasing.load(
        organizationId: organizationId,
        filter: filter,
      ),
    };
  }

  Future<ReportFilterOptions> loadFilterOptions(String organizationId) async {
    final products =
        await (_database.select(_database.products)
              ..where(
                (row) =>
                    row.organizationId.equals(organizationId) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.normalizedName)]))
            .get();
    final categories =
        await (_database.select(_database.categories)
              ..where(
                (row) =>
                    row.organizationId.equals(organizationId) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.normalizedName)]))
            .get();
    final users =
        await (_database.select(_database.appUsers)
              ..where(
                (row) =>
                    row.organizationId.equals(organizationId) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.displayName)]))
            .get();
    return ReportFilterOptions(
      products: [
        for (final product in products)
          ReportFilterOption(
            id: product.id,
            label: '${product.sku} · ${product.name}',
          ),
      ],
      categories: [
        for (final category in categories)
          ReportFilterOption(id: category.id, label: category.name),
      ],
      users: [
        for (final user in users)
          ReportFilterOption(id: user.id, label: user.displayName),
      ],
    );
  }
}
