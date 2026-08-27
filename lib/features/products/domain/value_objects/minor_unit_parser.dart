abstract final class MinorUnitParser {
  static int? tryParse(String input) {
    final value = input.trim().replaceAll(',', '');
    final match = RegExp(r'^(\d+)(?:\.(\d{0,2}))?$').firstMatch(value);
    if (match == null) {
      return null;
    }
    final whole = int.tryParse(match.group(1)!);
    if (whole == null) {
      return null;
    }
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    return whole * 100 + (fraction.isEmpty ? 0 : int.parse(fraction));
  }

  static String format(int minor) {
    final whole = minor ~/ 100;
    final fraction = (minor % 100).toString().padLeft(2, '0');
    return '$whole.$fraction';
  }
}
