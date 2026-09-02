import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import 'report_query_support.dart';

class InventoryMovementReportQuery {
  const InventoryMovementReportQuery(this._database);

  final AppDatabase _database;

  Future<ReportDataset> load({
    required String organizationId,
    required ReportFilter filter,
  }) async {
    final clauses = <String>[];
    final variables = scopedVariables(organizationId, filter);
    if (filter.productId case final value?) {
      clauses.add('ile.product_id = ?');
      variables.add(Variable<String>(value));
    }
    if (filter.categoryId case final value?) {
      clauses.add('p.category_id = ?');
      variables.add(Variable<String>(value));
    }
    if (filter.userId case final value?) {
      clauses.add('it.created_by_user_id = ?');
      variables.add(Variable<String>(value));
    }
    variables.addAll(pagedVariables(filter));
    final rows = await selectReportRows(
      _database,
      '''
        SELECT it.occurred_at, it.transaction_type, p.sku,
               p.name AS product, sl.name AS location,
               ile.quantity_delta_milli, ile.balance_after_milli,
               COALESCE(u.display_name, it.created_by_user_id) AS actor,
               COUNT(*) OVER() AS total_count
        FROM inventory_ledger_entries ile
        JOIN inventory_transactions it ON it.id = ile.transaction_id
        JOIN products p ON p.id = ile.product_id
        JOIN stock_locations sl ON sl.id = ile.stock_location_id
        LEFT JOIN app_users u ON u.id = it.created_by_user_id
        WHERE it.organization_id = ? AND it.branch_id = ?
          AND it.occurred_at >= ? AND it.occurred_at < ?
          ${clauses.isEmpty ? '' : 'AND ${clauses.join(' AND ')}'}
        ORDER BY it.occurred_at DESC, ile.id LIMIT ? OFFSET ?
      ''',
      variables: variables,
      readsFrom: {
        _database.inventoryTransactions,
        _database.inventoryLedgerEntries,
        _database.products,
        _database.stockLocations,
        _database.appUsers,
      },
    );
    return reportDataset(
      type: ReportType.inventoryMovement,
      filter: filter,
      totalRows: rows.isEmpty ? 0 : rows.first.read<int>('total_count'),
      rows: [
        for (final row in rows)
          ReportRow({
            'occurredAt': row.read<DateTime>('occurred_at'),
            'type': _label(row.read<String>('transaction_type')),
            'sku': row.read<String>('sku'),
            'product': row.read<String>('product'),
            'location': row.read<String>('location'),
            'quantityDeltaMilli': row.read<int>('quantity_delta_milli'),
            'balanceAfterMilli': row.read<int>('balance_after_milli'),
            'actor': row.read<String>('actor'),
          }),
      ],
    );
  }
}

String _label(String value) => value
    .split('_')
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
