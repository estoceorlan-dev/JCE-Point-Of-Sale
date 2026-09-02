import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import 'report_query_support.dart';

class InventoryReportQueries {
  const InventoryReportQueries(this._database);

  final AppDatabase _database;

  Future<ReportDataset> valuation({
    required String organizationId,
    required ReportFilter filter,
  }) {
    return _loadBalanceReport(
      organizationId: organizationId,
      filter: filter,
      lowStockOnly: false,
    );
  }

  Future<ReportDataset> lowStock({
    required String organizationId,
    required ReportFilter filter,
  }) {
    return _loadBalanceReport(
      organizationId: organizationId,
      filter: filter,
      lowStockOnly: true,
    );
  }

  Future<ReportDataset> _loadBalanceReport({
    required String organizationId,
    required ReportFilter filter,
    required bool lowStockOnly,
  }) async {
    final clauses = <String>[];
    final variables = <Variable<Object>>[
      Variable<String>(organizationId),
      Variable<String>(filter.branchId),
    ];
    if (filter.productId case final value?) {
      clauses.add('ib.product_id = ?');
      variables.add(Variable<String>(value));
    }
    if (filter.categoryId case final value?) {
      clauses.add('p.category_id = ?');
      variables.add(Variable<String>(value));
    }
    if (lowStockOnly) {
      clauses.add(
        '(ib.on_hand_milli - ib.reserved_milli) <= ib.reorder_point_milli',
      );
    }
    variables.addAll(pagedVariables(filter));
    final rows = await selectReportRows(
      _database,
      '''
        SELECT p.sku, p.name AS product, sl.name AS location,
               ib.on_hand_milli, ib.reserved_milli, ib.reorder_point_milli,
               ib.weighted_average_cost_minor,
               CAST((ib.on_hand_milli * ib.weighted_average_cost_minor +
                 CASE WHEN ib.on_hand_milli >= 0 THEN 500 ELSE -500 END) /
                 1000 AS INTEGER) AS valuation_minor,
               COUNT(*) OVER() AS total_count
        FROM inventory_balances ib
        JOIN products p ON p.id = ib.product_id
        JOIN stock_locations sl ON sl.id = ib.stock_location_id
        WHERE ib.organization_id = ? AND ib.branch_id = ?
          AND p.deleted_at IS NULL AND sl.deleted_at IS NULL
          ${clauses.isEmpty ? '' : 'AND ${clauses.join(' AND ')}'}
        ORDER BY ${lowStockOnly ? '(ib.on_hand_milli - ib.reserved_milli) ASC' : 'valuation_minor DESC'}, p.name
        LIMIT ? OFFSET ?
      ''',
      variables: variables,
      readsFrom: {
        _database.inventoryBalances,
        _database.products,
        _database.stockLocations,
      },
    );
    final type = lowStockOnly
        ? ReportType.lowStock
        : ReportType.inventoryValuation;
    return reportDataset(
      type: type,
      filter: filter,
      totalRows: rows.isEmpty ? 0 : rows.first.read<int>('total_count'),
      rows: [
        for (final row in rows)
          if (lowStockOnly)
            ReportRow({
              'sku': row.read<String>('sku'),
              'product': row.read<String>('product'),
              'location': row.read<String>('location'),
              'onHandMilli': row.read<int>('on_hand_milli'),
              'reservedMilli': row.read<int>('reserved_milli'),
              'availableMilli':
                  row.read<int>('on_hand_milli') -
                  row.read<int>('reserved_milli'),
              'reorderPointMilli': row.read<int>('reorder_point_milli'),
            })
          else
            ReportRow({
              'sku': row.read<String>('sku'),
              'product': row.read<String>('product'),
              'onHandMilli': row.read<int>('on_hand_milli'),
              'averageCostMinor': row.read<int>('weighted_average_cost_minor'),
              'valuationMinor': row.read<int>('valuation_minor'),
            }),
      ],
    );
  }
}
