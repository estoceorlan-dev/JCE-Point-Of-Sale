enum ReportValueFormat {
  text,
  integer,
  date,
  dateTime,
  moneyMinor,
  quantityMilli,
  percentageBasisPoints,
  durationMinutes,
}

class ReportColumn {
  const ReportColumn({
    required this.key,
    required this.label,
    this.format = ReportValueFormat.text,
  });

  final String key;
  final String label;
  final ReportValueFormat format;
}

class ReportRow {
  ReportRow(Map<String, Object?> values) : values = Map.unmodifiable(values);

  final Map<String, Object?> values;

  Object? operator [](String key) => values[key];
}

class ReportDataset {
  const ReportDataset({
    required this.title,
    required this.definition,
    required this.columns,
    required this.rows,
    required this.totalRows,
    required this.page,
    required this.pageSize,
  });

  final String title;
  final String definition;
  final List<ReportColumn> columns;
  final List<ReportRow> rows;
  final int totalRows;
  final int page;
  final int pageSize;

  int get totalPages => totalRows == 0 ? 1 : (totalRows / pageSize).ceil();
}
