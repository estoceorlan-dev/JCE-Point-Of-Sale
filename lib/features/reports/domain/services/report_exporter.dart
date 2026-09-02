import '../entities/report_dataset.dart';
import '../entities/report_filter.dart';

abstract interface class ReportExporter<T> {
  T export({required ReportDataset dataset, required ReportFilter filter});
}

class PrintableReportDocument {
  const PrintableReportDocument({
    required this.title,
    required this.definition,
    required this.period,
    required this.columns,
    required this.rows,
  });

  final String title;
  final String definition;
  final String period;
  final List<String> columns;
  final List<List<String>> rows;
}
