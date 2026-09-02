import '../../domain/entities/report_dataset.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/services/report_exporter.dart';
import 'report_value_formatter.dart';

class CsvReportExporter implements ReportExporter<String> {
  const CsvReportExporter();

  @override
  String export({
    required ReportDataset dataset,
    required ReportFilter filter,
  }) {
    final lines = <String>[
      dataset.columns.map((column) => _escape(column.label)).join(','),
      for (final row in dataset.rows)
        dataset.columns
            .map(
              (column) => _escape(
                ReportValueFormatter.export(row[column.key], column.format),
              ),
            )
            .join(','),
    ];
    return lines.join('\r\n');
  }

  String _escape(String value) =>
      '"${value.replaceAll('"', '""').replaceAll('\r', ' ').replaceAll('\n', ' ')}"';
}
