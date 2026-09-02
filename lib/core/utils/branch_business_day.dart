import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class UtcDateRange {
  const UtcDateRange({required this.start, required this.endExclusive});

  final DateTime start;
  final DateTime endExclusive;
}

/// Converts branch-local calendar dates to the UTC boundaries used by storage.
class BranchBusinessDay {
  BranchBusinessDay() {
    _initialize();
  }

  static bool _initialized = false;

  static void _initialize() {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    _initialized = true;
  }

  UtcDateRange range({
    required DateTime fromDate,
    required DateTime toDate,
    required String timezoneName,
  }) {
    final location = timezone.getLocation(timezoneName);
    final start = timezone.TZDateTime(
      location,
      fromDate.year,
      fromDate.month,
      fromDate.day,
    );
    final endExclusive = timezone.TZDateTime(
      location,
      toDate.year,
      toDate.month,
      toDate.day + 1,
    );
    return UtcDateRange(
      start: start.toUtc(),
      endExclusive: endExclusive.toUtc(),
    );
  }

  DateTime localDate(DateTime utc, String timezoneName) {
    final local = timezone.TZDateTime.from(
      utc.toUtc(),
      timezone.getLocation(timezoneName),
    );
    return DateTime(local.year, local.month, local.day);
  }
}
