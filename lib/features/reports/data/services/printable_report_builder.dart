import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/services/report_exporter.dart';
import 'report_value_formatter.dart';

class PrintableReportBuilder
    implements ReportExporter<PrintableReportDocument> {
  const PrintableReportBuilder();

  @override
  PrintableReportDocument export({
    required ReportDataset dataset,
    required ReportFilter filter,
  }) {
    return PrintableReportDocument(
      title: dataset.title,
      definition: dataset.definition,
      period:
          '${_date(filter.fromUtc)} to ${_date(filter.toUtcExclusive.subtract(const Duration(microseconds: 1)))} UTC boundaries',
      columns: dataset.columns.map((column) => column.label).toList(),
      rows: [
        for (final row in dataset.rows)
          [
            for (final column in dataset.columns)
              ReportValueFormatter.display(row[column.key], column.format),
          ],
      ],
    );
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
