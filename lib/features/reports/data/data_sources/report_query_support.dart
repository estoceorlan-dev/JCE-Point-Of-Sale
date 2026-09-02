import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_definitions.dart';
import '../../domain/entities/report_filter.dart';

typedef SqlFragment = ({String sql, List<Variable<Object>> variables});

SqlFragment saleOptionalFilters(ReportFilter filter, {String saleAlias = 's'}) {
  final clauses = <String>[];
  final variables = <Variable<Object>>[];
  if (filter.userId case final value?) {
    clauses.add('$saleAlias.cashier_user_id = ?');
    variables.add(Variable<String>(value));
  }
  if (filter.paymentMethod case final value?) {
    clauses.add(
      'EXISTS (SELECT 1 FROM payments filter_payment '
      'WHERE filter_payment.sale_id = $saleAlias.id '
      'AND filter_payment.payment_method = ?)',
    );
    variables.add(Variable<String>(value));
  }
  if (filter.productId case final value?) {
    clauses.add(
      'EXISTS (SELECT 1 FROM sale_items filter_item '
      'WHERE filter_item.sale_id = $saleAlias.id '
      'AND filter_item.product_id = ?)',
    );
    variables.add(Variable<String>(value));
  }
  if (filter.categoryId case final value?) {
    clauses.add(
      'EXISTS (SELECT 1 FROM sale_items filter_item '
      'JOIN products filter_product ON filter_product.id = filter_item.product_id '
      'WHERE filter_item.sale_id = $saleAlias.id '
      'AND filter_product.category_id = ?)',
    );
    variables.add(Variable<String>(value));
  }
  return (
    sql: clauses.isEmpty ? '' : ' AND ${clauses.join(' AND ')}',
    variables: variables,
  );
}

SqlFragment productOptionalFilters(
  ReportFilter filter, {
  String saleAlias = 's',
  String itemAlias = 'si',
  String productAlias = 'p',
}) {
  final sale = saleOptionalFilters(
    ReportFilter(
      branchId: filter.branchId,
      fromUtc: filter.fromUtc,
      toUtcExclusive: filter.toUtcExclusive,
      userId: filter.userId,
      paymentMethod: filter.paymentMethod,
    ),
    saleAlias: saleAlias,
  );
  final clauses = <String>[];
  final variables = <Variable<Object>>[...sale.variables];
  if (filter.productId case final value?) {
    clauses.add('$itemAlias.product_id = ?');
    variables.add(Variable<String>(value));
  }
  if (filter.categoryId case final value?) {
    clauses.add('$productAlias.category_id = ?');
    variables.add(Variable<String>(value));
  }
  return (
    sql: '${sale.sql}${clauses.isEmpty ? '' : ' AND ${clauses.join(' AND ')}'}',
    variables: variables,
  );
}

Future<List<QueryRow>> selectReportRows(
  AppDatabase database,
  String sql, {
  required List<Variable<Object>> variables,
  required Set<TableInfo<Table, Object?>> readsFrom,
}) {
  return database
      .customSelect(sql, variables: variables, readsFrom: readsFrom)
      .get();
}

ReportDataset reportDataset({
  required ReportType type,
  required ReportFilter filter,
  required List<ReportRow> rows,
  required int totalRows,
}) {
  final definition = ReportDefinitions.forType(type);
  return ReportDataset(
    title: definition.title,
    definition: definition.formula,
    columns: definition.columns,
    rows: rows,
    totalRows: totalRows,
    page: filter.page,
    pageSize: filter.pageSize,
  );
}

List<Variable<Object>> scopedVariables(
  String organizationId,
  ReportFilter filter,
) => [
  Variable<String>(organizationId),
  Variable<String>(filter.branchId),
  Variable<DateTime>(filter.fromUtc),
  Variable<DateTime>(filter.toUtcExclusive),
];

List<Variable<Object>> pagedVariables(ReportFilter filter) => [
  Variable<int>(filter.pageSize),
  Variable<int>(filter.offset),
];
