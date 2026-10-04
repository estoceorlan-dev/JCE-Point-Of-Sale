import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/sync/throttle_retry_policy.dart';

void main() {
  test('server retry floor is respected and positive jitter is bounded', () {
    expect(
      throttleRetryDelay(
        attemptCount: 1,
        details: {'retryAfterSeconds': 120},
        jitterSample: 0,
      ),
      const Duration(seconds: 120),
    );
    expect(
      throttleRetryDelay(
        attemptCount: 1,
        details: {'retryAfterSeconds': 120},
        jitterSample: 1,
      ),
      const Duration(seconds: 150),
    );
  });
  test(
    'malformed retry hints fall back safely and repeated retries back off',
    () {
      for (final value in [null, -1, '10', double.nan, double.infinity]) {
        expect(
          throttleRetryDelay(
            attemptCount: 1,
            details: {'retryAfterSeconds': value},
            jitterSample: 0,
          ),
          const Duration(minutes: 1),
        );
      }
      expect(
        throttleRetryDelay(attemptCount: 20, jitterSample: 0),
        const Duration(hours: 1),
      );
      expect(
        throttleRetryDelay(
          attemptCount: 1,
          details: {'retryAfterSeconds': 99999999},
          jitterSample: 0,
        ),
        const Duration(days: 1),
      );
    },
  );
}
