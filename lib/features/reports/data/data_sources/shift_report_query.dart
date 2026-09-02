import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import 'report_query_support.dart';

class ShiftReportQuery {
  const ShiftReportQuery(this._database);

  final AppDatabase _database;

  Future<ReportDataset> load({
    required String organizationId,
    required ReportFilter filter,
  }) async {
    final userClause = filter.userId == null
        ? ''
        : 'AND sh.opened_by_user_id = ?';
    final rows = await selectReportRows(
      _database,
      '''
        SELECT sh.opened_at, r.name AS register_name,
               COALESCE(u.display_name, sh.opened_by_user_id) AS cashier,
               sh.status, sh.expected_cash_minor, sh.counted_cash_minor,
               sh.discrepancy_minor, COUNT(*) OVER() AS total_count
        FROM shifts sh
        JOIN registers r ON r.id = sh.register_id
        LEFT JOIN app_users u ON u.id = sh.opened_by_user_id
        WHERE sh.organization_id = ? AND sh.branch_id = ?
          AND sh.opened_at >= ? AND sh.opened_at < ? $userClause
        ORDER BY sh.opened_at DESC LIMIT ? OFFSET ?
      ''',
      variables: [
        ...scopedVariables(organizationId, filter),
        if (filter.userId case final value?) Variable<String>(value),
        ...pagedVariables(filter),
      ],
      readsFrom: {_database.shifts, _database.registers, _database.appUsers},
    );
    return reportDataset(
      type: ReportType.shiftReconciliation,
      filter: filter,
      totalRows: rows.isEmpty ? 0 : rows.first.read<int>('total_count'),
      rows: [
        for (final row in rows)
          ReportRow({
            'openedAt': row.read<DateTime>('opened_at'),
            'register': row.read<String>('register_name'),
            'cashier': row.read<String>('cashier'),
            'status': _title(row.read<String>('status')),
            'expectedCashMinor': row.readNullable<int>('expected_cash_minor'),
            'countedCashMinor': row.readNullable<int>('counted_cash_minor'),
            'discrepancyMinor': row.readNullable<int>('discrepancy_minor'),
          }),
      ],
    );
  }
}

String _title(String value) => '${value[0].toUpperCase()}${value.substring(1)}';
