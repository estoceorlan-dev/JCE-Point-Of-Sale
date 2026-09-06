import '../../../../core/database/outbox_retry_policy.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../domain/entities/receipt_print_job.dart';
import '../../domain/entities/register_hardware_profile.dart';
import '../../domain/repositories/pos_hardware_repository.dart';
import '../../domain/services/receipt_printer.dart';

class PrintAttemptResult {
  const PrintAttemptResult({
    required this.jobId,
    required this.printed,
    required this.queuedForRetry,
    this.failure,
  });

  final String jobId;
  final bool printed;
  final bool queuedForRetry;
  final Failure? failure;
}

class ReceiptPrintQueueProcessor {
  const ReceiptPrintQueueProcessor({
    required PosHardwareRepository repository,
    required ReceiptPrinter printer,
    required AppClock clock,
    this.retryPolicy = const OutboxRetryPolicy(
      baseDelay: Duration(seconds: 2),
      maximumDelay: Duration(minutes: 5),
      maximumAttempts: 5,
    ),
  }) : _repository = repository,
       _printer = printer,
       _clock = clock;

  final PosHardwareRepository _repository;
  final ReceiptPrinter _printer;
  final AppClock _clock;
  final OutboxRetryPolicy retryPolicy;

  Future<List<PrintAttemptResult>> processDue({int limit = 10}) async {
    final jobs = await _repository.claimDueJobs(
      now: _clock.nowUtc(),
      limit: limit,
    );
    final results = <PrintAttemptResult>[];
    for (final job in jobs) {
      results.add(await _process(job));
    }
    return results;
  }

  Future<PrintAttemptResult> _process(ReceiptPrintJob job) async {
    final profile = await _repository.getProfile(
      organizationId: job.organizationId,
      branchId: job.branchId,
      registerId: job.registerId,
    );
    Result<void, Failure> result;
    if (profile == null ||
        profile.printerType != ReceiptPrinterType.networkEscPos) {
      result = const Result.failure(
        ValidationFailure(
          'The register no longer has a physical receipt printer configured.',
        ),
      );
    } else {
      result = await _printer.print(
        documentText: job.documentText,
        profile: profile,
      );
    }
    final now = _clock.nowUtc();
    if (result.isSuccess) {
      await _repository.markPrintSucceeded(jobId: job.id, printedAt: now);
      return PrintAttemptResult(
        jobId: job.id,
        printed: true,
        queuedForRetry: false,
      );
    }
    final attemptCount = job.attemptCount + 1;
    final permanent = retryPolicy.isPermanentFailure(attemptCount);
    final nextAttemptAt = permanent
        ? null
        : now.add(retryPolicy.delayForAttempt(attemptCount));
    final failure = result.failureOrNull!;
    await _repository.markPrintFailed(
      jobId: job.id,
      attemptCount: attemptCount,
      error: failure.message,
      failedAt: now,
      nextAttemptAt: nextAttemptAt,
    );
    return PrintAttemptResult(
      jobId: job.id,
      printed: false,
      queuedForRetry: nextAttemptAt != null,
      failure: failure,
    );
  }
}
