import '../../core/constants/app_constants.dart';

abstract final class Formatters {
  static String currency(num value) {
    return '${AppConstants.defaultCurrencyCode} ${value.toStringAsFixed(2)}';
  }

  static String currencyMinor(int value) {
    final sign = value < 0 ? '-' : '';
    final absolute = value.abs();
    final whole = absolute ~/ 100;
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '${AppConstants.defaultCurrencyCode} $sign$whole.$fraction';
  }

  static String quantityMilli(int value) {
    final sign = value < 0 ? '-' : '';
    final absolute = value.abs();
    final whole = absolute ~/ 1000;
    final fraction = (absolute % 1000).toString().padLeft(3, '0');
    final trimmedFraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    return trimmedFraction.isEmpty
        ? '$sign$whole'
        : '$sign$whole.$trimmedFraction';
  }

  static int? parseCurrencyMinor(String value) {
    final normalized = value.trim().replaceAll(',', '');
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
    if (match == null) return null;
    final whole = int.tryParse(match.group(2)!);
    if (whole == null) return null;
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    final minor = whole * 100 + (int.tryParse(fraction) ?? 0);
    return match.group(1) == '-' ? -minor : minor;
  }

  static int? parseQuantityMilli(String value) {
    final normalized = value.trim().replaceAll(',', '');
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,3}))?$').firstMatch(normalized);
    if (match == null) return null;
    final whole = int.tryParse(match.group(2)!);
    if (whole == null) return null;
    final fraction = (match.group(3) ?? '').padRight(3, '0');
    final fractionMilli = int.tryParse(fraction) ?? 0;
    final quantity = whole * 1000 + fractionMilli;
    return match.group(1) == '-' ? -quantity : quantity;
  }
}
