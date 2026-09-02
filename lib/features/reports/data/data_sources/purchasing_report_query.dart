import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import 'report_query_support.dart';

class PurchasingReportQuery {
  const PurchasingReportQuery(this._database);

  final AppDatabase _database;

  Future<ReportDataset> load({
    required String organizationId,
    required ReportFilter filter,
  }) async {
    final clauses = <String>[];
    final variables = scopedVariables(organizationId, filter);
    if (filter.userId case final value?) {
      clauses.add('po.created_by_user_id = ?');
      variables.add(Variable<String>(value));
    }
    if (filter.productId case final value?) {
      clauses.add(
        'EXISTS (SELECT 1 FROM purchase_order_items fi '
        'WHERE fi.purchase_order_id = po.id AND fi.product_id = ?)',
      );
      variables.add(Variable<String>(value));
    }
    if (filter.categoryId case final value?) {
      clauses.add(
        'EXISTS (SELECT 1 FROM purchase_order_items fi '
        'JOIN products fp ON fp.id = fi.product_id '
        'WHERE fi.purchase_order_id = po.id AND fp.category_id = ?)',
      );
      variables.add(Variable<String>(value));
    }
    variables.addAll(pagedVariables(filter));
    final rows = await selectReportRows(
      _database,
      '''
        SELECT po.order_number, sup.name AS supplier_name, po.status,
               COALESCE(SUM(poi.ordered_quantity_milli), 0) AS ordered,
               COALESCE(SUM(poi.received_quantity_milli), 0) AS received,
               COALESCE(SUM(poi.ordered_quantity_milli -
                 poi.received_quantity_milli - poi.cancelled_quantity_milli), 0) AS remaining,
               COALESCE(SUM(CAST((poi.ordered_quantity_milli *
                 poi.unit_cost_minor + 500) / 1000 AS INTEGER)), 0) AS ordered_value,
               COALESCE((SELECT SUM(CAST((gri.received_quantity_milli *
                 gri.landed_unit_cost_minor + 500) / 1000 AS INTEGER))
                 FROM goods_receipts gr JOIN goods_receipt_items gri
                   ON gri.goods_receipt_id = gr.id
                 WHERE gr.purchase_order_id = po.id), 0) AS received_cost,
               COUNT(*) OVER() AS total_count
        FROM purchase_orders po
        JOIN suppliers sup ON sup.id = po.supplier_id
        LEFT JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
        WHERE po.organization_id = ? AND po.branch_id = ?
          AND po.created_at >= ? AND po.created_at < ?
          ${clauses.isEmpty ? '' : 'AND ${clauses.join(' AND ')}'}
        GROUP BY po.id, po.order_number, sup.name, po.status
        ORDER BY po.created_at DESC LIMIT ? OFFSET ?
      ''',
      variables: variables,
      readsFrom: {
        _database.purchaseOrders,
        _database.purchaseOrderItems,
        _database.goodsReceipts,
        _database.goodsReceiptItems,
        _database.suppliers,
        _database.products,
      },
    );
    return reportDataset(
      type: ReportType.purchaseReceivingPerformance,
      filter: filter,
      totalRows: rows.isEmpty ? 0 : rows.first.read<int>('total_count'),
      rows: [
        for (final row in rows)
          ReportRow({
            'orderNumber': row.read<String>('order_number'),
            'supplier': row.read<String>('supplier_name'),
            'status': _title(row.read<String>('status')),
            'orderedMilli': row.read<int>('ordered'),
            'receivedMilli': row.read<int>('received'),
            'remainingMilli': row.read<int>('remaining'),
            'orderedValueMinor': row.read<int>('ordered_value'),
            'receivedCostMinor': row.read<int>('received_cost'),
          }),
      ],
    );
  }
}

String _title(String value) => value
    .split('_')
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
