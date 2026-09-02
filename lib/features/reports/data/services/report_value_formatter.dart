import '../../../../shared/utils/formatters.dart';
import '../../domain/entities/report_dataset.dart';

abstract final class ReportValueFormatter {
  static String display(Object? value, ReportValueFormat format) {
    if (value == null) return '—';
    return switch (format) {
      ReportValueFormat.moneyMinor => Formatters.currencyMinor(value as int),
      ReportValueFormat.quantityMilli => Formatters.quantityMilli(value as int),
      ReportValueFormat.percentageBasisPoints =>
        '${((value as int) / 100).toStringAsFixed(2)}%',
      ReportValueFormat.durationMinutes => '${value as int} min',
      ReportValueFormat.date => _date(value as DateTime),
      ReportValueFormat.dateTime => _dateTime(value as DateTime),
      ReportValueFormat.integer || ReportValueFormat.text => value.toString(),
    };
  }

  static String export(Object? value, ReportValueFormat format) {
    if (value == null) return '';
    return switch (format) {
      ReportValueFormat.moneyMinor ||
      ReportValueFormat.quantityMilli ||
      ReportValueFormat.percentageBasisPoints ||
      ReportValueFormat.durationMinutes => (value as int).toString(),
      ReportValueFormat.date => _date(value as DateTime),
      ReportValueFormat.dateTime =>
        (value as DateTime).toUtc().toIso8601String(),
      ReportValueFormat.integer || ReportValueFormat.text => value.toString(),
    };
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _dateTime(DateTime value) =>
      '${_date(value.toLocal())} ${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';
}
