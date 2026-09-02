import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/branch_business_day.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import 'report_query_support.dart';

class SalesSummaryReportQueries {
  const SalesSummaryReportQueries(this._database, this._businessDay);

  final AppDatabase _database;
  final BranchBusinessDay _businessDay;

  Future<ReportDataset> dailySales({
    required String organizationId,
    required String timezoneName,
    required ReportFilter filter,
  }) async {
    final saleFilter = saleOptionalFilters(filter);
    final returnFilter = saleOptionalFilters(filter);
    final rows = await selectReportRows(
      _database,
      '''
        SELECT s.completed_at AS occurred_at, 'sale' AS fact_type,
               s.total_minor AS amount_minor, b.name AS branch_name
        FROM sales s
        JOIN branches b ON b.id = s.branch_id
        WHERE s.organization_id = ? AND s.branch_id = ?
          AND s.completed_at >= ? AND s.completed_at < ?
          AND s.status IN ('completed', 'partially_returned', 'returned')
          ${saleFilter.sql}
        UNION ALL
        SELECT sr.completed_at AS occurred_at, 'return' AS fact_type,
               sr.total_minor AS amount_minor, b.name AS branch_name
        FROM sale_returns sr
        JOIN sales s ON s.id = sr.sale_id
        JOIN branches b ON b.id = sr.branch_id
        WHERE sr.organization_id = ? AND sr.branch_id = ?
          AND sr.completed_at >= ? AND sr.completed_at < ?
          AND sr.status = 'completed' AND sr.correction_type = 'return'
          ${returnFilter.sql}
        ORDER BY occurred_at DESC
      ''',
      variables: [
        ...scopedVariables(organizationId, filter),
        ...saleFilter.variables,
        ...scopedVariables(organizationId, filter),
        ...returnFilter.variables,
      ],
      readsFrom: {
        _database.sales,
        _database.saleReturns,
        _database.saleItems,
        _database.payments,
        _database.products,
        _database.branches,
      },
    );
    final groups = <DateTime, _DailySalesBuilder>{};
    for (final row in rows) {
      final day = _businessDay.localDate(
        row.read<DateTime>('occurred_at'),
        timezoneName,
      );
      final builder = groups.putIfAbsent(
        day,
        () => _DailySalesBuilder(row.read<String>('branch_name')),
      );
      final amount = row.read<int>('amount_minor');
      if (row.read<String>('fact_type') == 'sale') {
        builder.transactions++;
        builder.grossSalesMinor += amount;
      } else {
        builder.returnsMinor += amount;
      }
    }
    final sorted = groups.entries.toList()
      ..sort((left, right) => right.key.compareTo(left.key));
    final pageRows = sorted.skip(filter.offset).take(filter.pageSize);
    return reportDataset(
      type: ReportType.dailyBranchSales,
      filter: filter,
      totalRows: sorted.length,
      rows: [
        for (final entry in pageRows)
          ReportRow({
            'businessDate': entry.key,
            'branch': entry.value.branch,
            'transactions': entry.value.transactions,
            'grossSalesMinor': entry.value.grossSalesMinor,
            'returnsMinor': entry.value.returnsMinor,
            'netSalesMinor':
                entry.value.grossSalesMinor - entry.value.returnsMinor,
          }),
      ],
    );
  }

  Future<ReportDataset> paymentTotals({
    required String organizationId,
    required ReportFilter filter,
  }) async {
    final saleFilter = saleOptionalFilters(filter);
    final returnFilter = saleOptionalFilters(filter);
    final paymentClause = filter.paymentMethod == null
        ? ''
        : ' AND p.payment_method = ?';
    final refundClause = filter.paymentMethod == null
        ? ''
        : ' AND rp.refund_method = ?';
    final rows = await selectReportRows(
      _database,
      '''
        WITH facts AS (
          SELECT p.payment_method AS method, p.applied_amount_minor AS paid,
                 0 AS refunded
          FROM payments p JOIN sales s ON s.id = p.sale_id
          WHERE s.organization_id = ? AND s.branch_id = ?
            AND s.completed_at >= ? AND s.completed_at < ?
            AND s.status IN ('completed', 'partially_returned', 'returned')
            ${saleFilter.sql}$paymentClause
          UNION ALL
          SELECT rp.refund_method AS method, 0 AS paid,
                 rp.amount_minor AS refunded
          FROM refund_payments rp
          JOIN sale_returns sr ON sr.id = rp.sale_return_id
          JOIN sales s ON s.id = sr.sale_id
          WHERE sr.organization_id = ? AND sr.branch_id = ?
            AND sr.completed_at >= ? AND sr.completed_at < ?
            AND sr.status = 'completed' AND sr.correction_type = 'return'
            ${returnFilter.sql}$refundClause
        )
        SELECT method, SUM(paid) AS paid, SUM(refunded) AS refunded,
               COUNT(*) OVER() AS total_count
        FROM facts GROUP BY method ORDER BY method LIMIT ? OFFSET ?
      ''',
      variables: [
        ...scopedVariables(organizationId, filter),
        ...saleFilter.variables,
        if (filter.paymentMethod case final value?) Variable<String>(value),
        ...scopedVariables(organizationId, filter),
        ...returnFilter.variables,
        if (filter.paymentMethod case final value?) Variable<String>(value),
        ...pagedVariables(filter),
      ],
      readsFrom: {
        _database.payments,
        _database.refundPayments,
        _database.sales,
        _database.saleReturns,
        _database.saleItems,
        _database.products,
      },
    );
    return reportDataset(
      type: ReportType.paymentMethodTotals,
      filter: filter,
      totalRows: rows.isEmpty ? 0 : rows.first.read<int>('total_count'),
      rows: [
        for (final row in rows)
          ReportRow({
            'paymentMethod': _paymentLabel(row.read<String>('method')),
            'paymentsMinor': row.read<int>('paid'),
            'refundsMinor': row.read<int>('refunded'),
            'netMinor': row.read<int>('paid') - row.read<int>('refunded'),
          }),
      ],
    );
  }
}

class _DailySalesBuilder {
  _DailySalesBuilder(this.branch);

  final String branch;
  int transactions = 0;
  int grossSalesMinor = 0;
  int returnsMinor = 0;
}

String _paymentLabel(String value) => switch (value) {
  'e_wallet' => 'E-wallet',
  'store_credit' => 'Store credit',
  _ => '${value[0].toUpperCase()}${value.substring(1)}',
};
