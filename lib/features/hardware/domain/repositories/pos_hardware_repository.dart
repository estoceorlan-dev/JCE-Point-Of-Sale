import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/receipt_print_job.dart';
import '../entities/register_hardware_profile.dart';

abstract interface class PosHardwareRepository {
  Stream<RegisterHardwareProfile?> watchProfile({
    required BusinessContext context,
    required String registerId,
  });

  Future<RegisterHardwareProfile?> getProfile({
    required String organizationId,
    required String branchId,
    required String registerId,
  });

  Future<RegisterHardwareProfile?> getProfileForDevice({
    required String organizationId,
    required String branchId,
    required String deviceId,
  });

  Future<Result<void, Failure>> configureProfile({
    required BusinessContext context,
    required RegisterHardwareProfileDraft draft,
  });

  Future<Result<ReceiptPrintJob?, Failure>> enqueueReceipt({
    required BusinessContext context,
    required ReceiptPrintRequest request,
  });

  Future<List<ReceiptPrintJob>> claimDueJobs({
    required DateTime now,
    int limit = 10,
  });

  Future<void> markPrintSucceeded({
    required String jobId,
    required DateTime printedAt,
  });

  Future<void> markPrintFailed({
    required String jobId,
    required int attemptCount,
    required String error,
    required DateTime failedAt,
    required DateTime? nextAttemptAt,
  });

  Future<void> recoverInterruptedJobs({required DateTime now});
}
