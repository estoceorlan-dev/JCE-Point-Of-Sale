import 'dart:math';

import '../database/outbox_retry_policy.dart';

/// Throttling is a pause, never a reason to discard or reject a business write.
Duration throttleRetryDelay({
  required int attemptCount,
  Object? details,
  double? jitterSample,
}) {
  final raw = details is Map ? details['retryAfterSeconds'] : null;
  final seconds = raw is num && raw.isFinite && raw > 0
      ? raw.ceil().clamp(1, 86400)
      : 60;
  final backoff = const OutboxRetryPolicy().delayForAttempt(attemptCount);
  final floor = max(seconds * 1000, backoff.inMilliseconds);
  final sample = (jitterSample ?? Random().nextDouble()).clamp(0.0, 1.0);
  final jitter = (min(floor ~/ 4, 30000) * sample).round();
  return Duration(milliseconds: floor + jitter);
}
