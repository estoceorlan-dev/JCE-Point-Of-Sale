import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import 'report_query_support.dart';

class TransferReportQuery {
  const TransferReportQuery(this._database);

  final AppDatabase _database;

  Future<ReportDataset> load({
    required String organizationId,
    required ReportFilter filter,
  }) async {
    final clauses = <String>[];
    final variables = <Variable<Object>>[
      Variable<String>(organizationId),
      Variable<String>(filter.branchId),
      Variable<String>(filter.branchId),
      Variable<DateTime>(filter.fromUtc),
      Variable<DateTime>(filter.toUtcExclusive),
    ];
    if (filter.userId case final value?) {
      clauses.add('st.created_by_user_id = ?');
      variables.add(Variable<String>(value));
    }
    if (filter.productId case final value?) {
      clauses.add(
        'EXISTS (SELECT 1 FROM stock_transfer_items fi '
        'WHERE fi.transfer_id = st.id AND fi.product_id = ?)',
      );
      variables.add(Variable<String>(value));
    }
    if (filter.categoryId case final value?) {
      clauses.add(
        'EXISTS (SELECT 1 FROM stock_transfer_items fi '
        'JOIN products fp ON fp.id = fi.product_id '
        'WHERE fi.transfer_id = st.id AND fp.category_id = ?)',
      );
      variables.add(Variable<String>(value));
    }
    variables.addAll(pagedVariables(filter));
    final rows = await selectReportRows(
      _database,
      '''
        SELECT st.transfer_number, sb.name AS source_name,
               db.name AS destination_name, st.status,
               COALESCE(SUM(sti.requested_quantity_milli), 0) AS requested,
               COALESCE(SUM(sti.shipped_quantity_milli), 0) AS shipped,
               COALESCE(SUM(sti.received_quantity_milli), 0) AS received,
               COALESCE(SUM(sti.damaged_quantity_milli), 0) AS damaged,
               CASE WHEN st.shipped_at IS NULL OR st.received_at IS NULL
                    THEN NULL ELSE CAST((julianday(st.received_at) -
                    julianday(st.shipped_at)) * 1440 AS INTEGER) END AS lead_minutes,
               COUNT(*) OVER() AS total_count
        FROM stock_transfers st
        JOIN branches sb ON sb.id = st.source_branch_id
        JOIN branches db ON db.id = st.destination_branch_id
        LEFT JOIN stock_transfer_items sti ON sti.transfer_id = st.id
        WHERE st.organization_id = ?
          AND (st.source_branch_id = ? OR st.destination_branch_id = ?)
          AND st.created_at >= ? AND st.created_at < ?
          ${clauses.isEmpty ? '' : 'AND ${clauses.join(' AND ')}'}
        GROUP BY st.id, st.transfer_number, sb.name, db.name, st.status,
                 st.shipped_at, st.received_at
        ORDER BY st.created_at DESC LIMIT ? OFFSET ?
      ''',
      variables: variables,
      readsFrom: {
        _database.stockTransfers,
        _database.stockTransferItems,
        _database.products,
        _database.branches,
      },
    );
    return reportDataset(
      type: ReportType.transferPerformance,
      filter: filter,
      totalRows: rows.isEmpty ? 0 : rows.first.read<int>('total_count'),
      rows: [
        for (final row in rows)
          ReportRow({
            'transferNumber': row.read<String>('transfer_number'),
            'source': row.read<String>('source_name'),
            'destination': row.read<String>('destination_name'),
            'status': _title(row.read<String>('status')),
            'requestedMilli': row.read<int>('requested'),
            'shippedMilli': row.read<int>('shipped'),
            'receivedMilli': row.read<int>('received'),
            'damagedMilli': row.read<int>('damaged'),
            'leadMinutes': row.readNullable<int>('lead_minutes'),
          }),
      ],
    );
  }
}

String _title(String value) => value
    .split('_')
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
