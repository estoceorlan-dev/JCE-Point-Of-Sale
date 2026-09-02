import '../../../../core/database/app_database.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import 'report_query_support.dart';

class SalesPerformanceReportQueries {
  const SalesPerformanceReportQueries(this._database);

  final AppDatabase _database;

  Future<ReportDataset> cashierPerformance({
    required String organizationId,
    required ReportFilter filter,
  }) async {
    final saleFilter = saleOptionalFilters(filter);
    final returnFilter = saleOptionalFilters(filter);
    final rows = await selectReportRows(
      _database,
      '''
        WITH facts AS (
          SELECT s.cashier_user_id AS user_id, u.display_name AS cashier,
                 1 AS transactions, s.total_minor AS gross_sales, 0 AS returns
          FROM sales s
          LEFT JOIN app_users u ON u.id = s.cashier_user_id
          WHERE s.organization_id = ? AND s.branch_id = ?
            AND s.completed_at >= ? AND s.completed_at < ?
            AND s.status IN ('completed', 'partially_returned', 'returned')
            ${saleFilter.sql}
          UNION ALL
          SELECT s.cashier_user_id AS user_id, u.display_name AS cashier,
                 0 AS transactions, 0 AS gross_sales, sr.total_minor AS returns
          FROM sale_returns sr
          JOIN sales s ON s.id = sr.sale_id
          LEFT JOIN app_users u ON u.id = s.cashier_user_id
          WHERE sr.organization_id = ? AND sr.branch_id = ?
            AND sr.completed_at >= ? AND sr.completed_at < ?
            AND sr.status = 'completed' AND sr.correction_type = 'return'
            ${returnFilter.sql}
        )
        SELECT user_id, COALESCE(cashier, user_id) AS cashier,
               SUM(transactions) AS transactions,
               SUM(gross_sales) AS gross_sales, SUM(returns) AS returns,
               COUNT(*) OVER() AS total_count
        FROM facts GROUP BY user_id, cashier
        ORDER BY gross_sales - returns DESC LIMIT ? OFFSET ?
      ''',
      variables: [
        ...scopedVariables(organizationId, filter),
        ...saleFilter.variables,
        ...scopedVariables(organizationId, filter),
        ...returnFilter.variables,
        ...pagedVariables(filter),
      ],
      readsFrom: {
        _database.sales,
        _database.saleReturns,
        _database.saleItems,
        _database.payments,
        _database.products,
        _database.appUsers,
      },
    );
    return reportDataset(
      type: ReportType.cashierPerformance,
      filter: filter,
      totalRows: rows.isEmpty ? 0 : rows.first.read<int>('total_count'),
      rows: [
        for (final row in rows)
          ReportRow({
            'cashier': row.read<String>('cashier'),
            'transactions': row.read<int>('transactions'),
            'grossSalesMinor': row.read<int>('gross_sales'),
            'returnsMinor': row.read<int>('returns'),
            'netSalesMinor':
                row.read<int>('gross_sales') - row.read<int>('returns'),
            'averageTicketMinor': row.read<int>('transactions') == 0
                ? 0
                : (row.read<int>('gross_sales') - row.read<int>('returns')) ~/
                      row.read<int>('transactions'),
          }),
      ],
    );
  }

  Future<ReportDataset> productSales({
    required String organizationId,
    required ReportFilter filter,
  }) {
    return _productReport(
      organizationId: organizationId,
      filter: filter,
      type: ReportType.productSales,
    );
  }

  Future<ReportDataset> grossProfit({
    required String organizationId,
    required ReportFilter filter,
  }) {
    return _productReport(
      organizationId: organizationId,
      filter: filter,
      type: ReportType.grossProfitEstimate,
    );
  }

  Future<ReportDataset> _productReport({
    required String organizationId,
    required ReportFilter filter,
    required ReportType type,
  }) async {
    final saleFilter = productOptionalFilters(filter);
    final returnFilter = productOptionalFilters(
      filter,
      itemAlias: 'si',
      productAlias: 'p',
    );
    final rows = await selectReportRows(
      _database,
      '''
        WITH facts AS (
          SELECT si.product_id, si.sku_snapshot AS sku,
                 si.product_name_snapshot AS product,
                 si.quantity_milli AS sold_quantity, 0 AS returned_quantity,
                 si.total_amount_minor AS revenue,
                 CAST((si.unit_cost_minor_snapshot * si.quantity_milli + 500) / 1000 AS INTEGER) AS cost
          FROM sale_items si
          JOIN sales s ON s.id = si.sale_id
          JOIN products p ON p.id = si.product_id
          WHERE s.organization_id = ? AND s.branch_id = ?
            AND s.completed_at >= ? AND s.completed_at < ?
            AND s.status IN ('completed', 'partially_returned', 'returned')
            ${saleFilter.sql}
          UNION ALL
          SELECT sri.product_id, si.sku_snapshot AS sku,
                 si.product_name_snapshot AS product,
                 0 AS sold_quantity, sri.quantity_milli AS returned_quantity,
                 -sri.total_minor AS revenue,
                 -CAST((si.unit_cost_minor_snapshot * sri.quantity_milli + 500) / 1000 AS INTEGER) AS cost
          FROM sale_return_items sri
          JOIN sale_returns sr ON sr.id = sri.sale_return_id
          JOIN sales s ON s.id = sr.sale_id
          JOIN sale_items si ON si.id = sri.sale_item_id
          JOIN products p ON p.id = sri.product_id
          WHERE sr.organization_id = ? AND sr.branch_id = ?
            AND sr.completed_at >= ? AND sr.completed_at < ?
            AND sr.status = 'completed' AND sr.correction_type = 'return'
            ${returnFilter.sql}
        )
        SELECT product_id, sku, product, SUM(sold_quantity) AS sold_quantity,
               SUM(returned_quantity) AS returned_quantity,
               SUM(revenue) AS revenue, SUM(cost) AS cost,
               COUNT(*) OVER() AS total_count
        FROM facts GROUP BY product_id, sku, product
        ORDER BY revenue DESC, product LIMIT ? OFFSET ?
      ''',
      variables: [
        ...scopedVariables(organizationId, filter),
        ...saleFilter.variables,
        ...scopedVariables(organizationId, filter),
        ...returnFilter.variables,
        ...pagedVariables(filter),
      ],
      readsFrom: {
        _database.sales,
        _database.saleItems,
        _database.saleReturns,
        _database.saleReturnItems,
        _database.payments,
        _database.products,
      },
    );
    return reportDataset(
      type: type,
      filter: filter,
      totalRows: rows.isEmpty ? 0 : rows.first.read<int>('total_count'),
      rows: [
        for (final row in rows)
          if (type == ReportType.productSales)
            ReportRow({
              'sku': row.read<String>('sku'),
              'product': row.read<String>('product'),
              'soldQuantityMilli': row.read<int>('sold_quantity'),
              'returnedQuantityMilli': row.read<int>('returned_quantity'),
              'netQuantityMilli':
                  row.read<int>('sold_quantity') -
                  row.read<int>('returned_quantity'),
              'netRevenueMinor': row.read<int>('revenue'),
            })
          else
            ReportRow({
              'sku': row.read<String>('sku'),
              'product': row.read<String>('product'),
              'netRevenueMinor': row.read<int>('revenue'),
              'estimatedCostMinor': row.read<int>('cost'),
              'grossProfitMinor':
                  row.read<int>('revenue') - row.read<int>('cost'),
              'marginBasisPoints': _margin(
                row.read<int>('revenue'),
                row.read<int>('cost'),
              ),
            }),
      ],
    );
  }
}

int _margin(int revenue, int cost) =>
    revenue == 0 ? 0 : ((revenue - cost) * 10000) ~/ revenue;
