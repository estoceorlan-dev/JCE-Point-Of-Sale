import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../../../../shared/models/permission.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../auth/domain/usecases/require_permission_usecase.dart';
import '../entities/stock_transfer.dart';
import '../repositories/transfers_repository.dart';
import 'transfer_use_case_context.dart';

class TransferWorkflowUseCase {
  const TransferWorkflowUseCase({
    required TransfersRepository repository,
    required RequirePermissionUseCase requirePermission,
  }) : _repository = repository,
       _requirePermission = requirePermission;

  final TransfersRepository _repository;
  final RequirePermissionUseCase _requirePermission;

  Future<Result<void, Failure>> submit({
    required AuthSession? session,
    required StockTransfer transfer,
  }) {
    final context = _context(session, AppPermission.manageInventory);
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.submit(
      context: context.valueOrNull!,
      transferId: transfer.id,
      expectedVersion: transfer.version,
    );
  }

  Future<Result<void, Failure>> approve({
    required AuthSession? session,
    required StockTransfer transfer,
  }) {
    final context = _approvalContext(session, transfer);
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.approve(
      context: context.valueOrNull!,
      transferId: transfer.id,
      expectedVersion: transfer.version,
    );
  }

  Future<Result<void, Failure>> reject({
    required AuthSession? session,
    required StockTransfer transfer,
    required String reason,
  }) {
    final context = _approvalContext(session, transfer);
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.reject(
      context: context.valueOrNull!,
      transferId: transfer.id,
      expectedVersion: transfer.version,
      reason: reason,
    );
  }

  Future<Result<void, Failure>> ship({
    required AuthSession? session,
    required StockTransfer transfer,
  }) {
    final context = _context(session, AppPermission.manageInventory);
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.ship(
      context: context.valueOrNull!,
      transferId: transfer.id,
      expectedVersion: transfer.version,
    );
  }

  Future<Result<void, Failure>> receive({
    required AuthSession? session,
    required StockTransfer transfer,
    required TransferReceiptDraft draft,
  }) {
    final context = _context(session, AppPermission.manageInventory);
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.receive(
      context: context.valueOrNull!,
      transferId: transfer.id,
      expectedVersion: transfer.version,
      draft: draft,
    );
  }

  Future<Result<void, Failure>> correctReceipt({
    required AuthSession? session,
    required StockTransfer transfer,
    required TransferCorrectionDraft draft,
  }) {
    final context = _context(session, AppPermission.approveTransfers);
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.correctReceipt(
      context: context.valueOrNull!,
      transferId: transfer.id,
      expectedVersion: transfer.version,
      draft: draft,
      approvedByUserId: context.valueOrNull!.actorUserId,
    );
  }

  Future<Result<void, Failure>> cancel({
    required AuthSession? session,
    required StockTransfer transfer,
    required String reason,
  }) {
    final context = _context(session, AppPermission.manageInventory);
    if (context case FailureResult(:final failure)) {
      return Future.value(Result.failure(failure));
    }
    return _repository.cancel(
      context: context.valueOrNull!,
      transferId: transfer.id,
      expectedVersion: transfer.version,
      reason: reason,
    );
  }

  Result<BusinessContext, Failure> _context(
    AuthSession? session,
    AppPermission permission,
  ) => requireTransferContext(
    session: session,
    requirePermission: _requirePermission,
    permission: permission,
  );

  Result<BusinessContext, Failure> _approvalContext(
    AuthSession? session,
    StockTransfer transfer,
  ) {
    final context = _context(session, AppPermission.approveTransfers);
    if (context case FailureResult()) return context;
    final organization = session!.activeOrganization;
    final destination = organization.branchById(transfer.destinationBranchId);
    if (destination == null ||
        !organization
            .permissionsFor(transfer.destinationBranchId)
            .contains(AppPermission.approveTransfers)) {
      return const Result.failure(
        AuthorizationFailure(
          'Transfer approval requires assignment to both branches.',
        ),
      );
    }
    return context;
  }
}
