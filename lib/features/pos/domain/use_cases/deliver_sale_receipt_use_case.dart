import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../../../hardware/data/services/receipt_print_queue_processor.dart';
import '../../../hardware/domain/entities/receipt_print_job.dart';
import '../../../hardware/domain/entities/register_hardware_profile.dart';
import '../../../hardware/domain/repositories/pos_hardware_repository.dart';
import '../entities/sale.dart';
import '../services/receipt_renderer.dart';

class DeliverSaleReceiptUseCase {
  const DeliverSaleReceiptUseCase({
    required PosHardwareRepository repository,
    required ReceiptPrintQueueProcessor processor,
    required ReceiptRenderer renderer,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _processor = processor,
       _renderer = renderer,
       _requirePermission = requirePermission;

  final PosHardwareRepository _repository;
  final ReceiptPrintQueueProcessor _processor;
  final ReceiptRenderer _renderer;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<ReceiptDeliveryResult, Failure>> call({
    required AuthSession? session,
    required SaleRecord sale,
    required bool isReprint,
  }) async {
    final context = _context(session, sale);
    if (context case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final profile = await _repository.getProfile(
      organizationId: context.valueOrNull!.organizationId,
      branchId: context.valueOrNull!.branchId,
      registerId: sale.registerId,
    );
    if (profile == null || profile.printerType == ReceiptPrinterType.screen) {
      return const Result.success(
        ReceiptDeliveryResult(
          screenReceiptAvailable: true,
          message: 'No physical printer is configured. Use screen or PDF.',
        ),
      );
    }
    final document = _renderer.render(sale, isReprint: isReprint);
    final queued = await _repository.enqueueReceipt(
      context: context.valueOrNull!,
      request: ReceiptPrintRequest(
        saleId: sale.id,
        registerId: sale.registerId,
        documentText: document.plainText,
        copyType: isReprint
            ? ReceiptCopyType.reprint
            : ReceiptCopyType.original,
      ),
    );
    if (queued case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final job = queued.valueOrNull;
    if (job == null) {
      return const Result.success(
        ReceiptDeliveryResult(screenReceiptAvailable: true),
      );
    }
    final attempts = await _processor.processDue();
    final attempt = attempts
        .where((value) => value.jobId == job.id)
        .firstOrNull;
    return Result.success(
      ReceiptDeliveryResult(
        screenReceiptAvailable: true,
        jobId: job.id,
        printed:
            attempt?.printed ?? job.status == ReceiptPrintJobStatus.succeeded,
        queuedForRetry:
            attempt?.queuedForRetry ??
            job.status == ReceiptPrintJobStatus.pending ||
                job.status == ReceiptPrintJobStatus.retryableFailure,
        message: attempt?.failure?.message,
      ),
    );
  }

  Result<BusinessContext, Failure> _context(
    AuthSession? session,
    SaleRecord sale,
  ) {
    if (session == null) {
      return const Result.failure(
        AuthorizationFailure('Authentication is required.'),
      );
    }
    if (sale.branchId != session.activeBranchId) {
      return const Result.failure(
        AuthorizationFailure('The receipt is outside the active branch.'),
      );
    }
    final authorization = _requirePermission(
      session: session,
      permission: AppPermission.processSales,
      organizationId: session.activeOrganizationId,
      branchId: session.activeBranchId,
    );
    if (authorization case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    return Result.success(
      BusinessContext(
        organizationId: session.activeOrganizationId,
        branchId: session.activeBranchId,
        actorUserId: session.activeOrganization.appUserId,
      ),
    );
  }
}
