import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/dashboard_summary.dart';

class DashboardLocalDataSource {
  const DashboardLocalDataSource(this._database);

  final AppDatabase _database;

  Stream<DashboardSummary> watchSummary({
    required String organizationId,
    required String branchId,
    required DateTime fromUtc,
    required DateTime toUtcExclusive,
  }) {
    return _database
        .customSelect(
          '''
          SELECT
            (SELECT COALESCE(SUM(total_minor), 0) FROM sales
             WHERE organization_id = ? AND branch_id = ?
               AND completed_at >= ? AND completed_at < ?
               AND status IN ('completed', 'partially_returned', 'returned'))
            -
            (SELECT COALESCE(SUM(total_minor), 0) FROM sale_returns
             WHERE organization_id = ? AND branch_id = ?
               AND completed_at >= ? AND completed_at < ?
               AND status = 'completed' AND correction_type = 'return')
              AS net_sales_minor,
            (SELECT COUNT(*) FROM sales
             WHERE organization_id = ? AND branch_id = ?
               AND completed_at >= ? AND completed_at < ?
               AND status IN ('completed', 'partially_returned', 'returned'))
              AS completed_sales,
            (SELECT COUNT(*) FROM sales
             WHERE organization_id = ? AND branch_id = ? AND status = 'draft')
              AS open_carts,
            (SELECT COUNT(*) FROM inventory_balances
             WHERE organization_id = ? AND branch_id = ?
               AND (on_hand_milli - reserved_milli) <= reorder_point_milli)
              AS low_stock_items,
            (SELECT COALESCE(SUM(si.total_amount_minor -
               CAST((si.unit_cost_minor_snapshot * si.quantity_milli + 500) /
               1000 AS INTEGER)), 0)
             FROM sale_items si JOIN sales s ON s.id = si.sale_id
             WHERE s.organization_id = ? AND s.branch_id = ?
               AND s.completed_at >= ? AND s.completed_at < ?
               AND s.status IN ('completed', 'partially_returned', 'returned'))
            -
            (SELECT COALESCE(SUM(sri.total_minor -
               CAST((si.unit_cost_minor_snapshot * sri.quantity_milli + 500) /
               1000 AS INTEGER)), 0)
             FROM sale_return_items sri
             JOIN sale_returns sr ON sr.id = sri.sale_return_id
             JOIN sale_items si ON si.id = sri.sale_item_id
             WHERE sr.organization_id = ? AND sr.branch_id = ?
               AND sr.completed_at >= ? AND sr.completed_at < ?
               AND sr.status = 'completed' AND sr.correction_type = 'return')
              AS gross_profit_minor
          ''',
          variables: [
            for (var occurrence = 0; occurrence < 2; occurrence++) ...[
              Variable<String>(organizationId),
              Variable<String>(branchId),
              Variable<DateTime>(fromUtc),
              Variable<DateTime>(toUtcExclusive),
            ],
            Variable<String>(organizationId),
            Variable<String>(branchId),
            Variable<DateTime>(fromUtc),
            Variable<DateTime>(toUtcExclusive),
            Variable<String>(organizationId),
            Variable<String>(branchId),
            Variable<String>(organizationId),
            Variable<String>(branchId),
            for (var occurrence = 0; occurrence < 2; occurrence++) ...[
              Variable<String>(organizationId),
              Variable<String>(branchId),
              Variable<DateTime>(fromUtc),
              Variable<DateTime>(toUtcExclusive),
            ],
          ],
          readsFrom: {
            _database.sales,
            _database.saleItems,
            _database.saleReturns,
            _database.saleReturnItems,
            _database.inventoryBalances,
          },
        )
        .watchSingle()
        .map(
          (row) => DashboardSummary(
            netSalesMinor: row.read<int>('net_sales_minor'),
            completedSales: row.read<int>('completed_sales'),
            openCarts: row.read<int>('open_carts'),
            lowStockItems: row.read<int>('low_stock_items'),
            grossProfitMinor: row.read<int>('gross_profit_minor'),
          ),
        );
  }
}
