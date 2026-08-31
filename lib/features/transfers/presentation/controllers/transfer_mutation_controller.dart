import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/use_cases/transfer_workflow_use_case.dart';
import '../providers/transfers_providers.dart';

final transferMutationControllerProvider =
    AsyncNotifierProvider<TransferMutationController, void>(
      TransferMutationController.new,
    );

class TransferMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<String, Failure>> create(StockTransferDraft draft) async {
    state = const AsyncLoading();
    final result = await ref.read(createTransferDraftUseCaseProvider)(
      session: ref.read(activeTransferSessionProvider),
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> submit(StockTransfer transfer) => _run(
    (workflow, session) =>
        workflow.submit(session: session, transfer: transfer),
  );

  Future<Result<void, Failure>> approve(StockTransfer transfer) => _run(
    (workflow, session) =>
        workflow.approve(session: session, transfer: transfer),
  );

  Future<Result<void, Failure>> reject(StockTransfer transfer, String reason) =>
      _run(
        (workflow, session) => workflow.reject(
          session: session,
          transfer: transfer,
          reason: reason,
        ),
      );

  Future<Result<void, Failure>> ship(StockTransfer transfer) => _run(
    (workflow, session) => workflow.ship(session: session, transfer: transfer),
  );

  Future<Result<void, Failure>> receive(
    StockTransfer transfer,
    TransferReceiptDraft draft,
  ) => _run(
    (workflow, session) =>
        workflow.receive(session: session, transfer: transfer, draft: draft),
  );

  Future<Result<void, Failure>> correctReceipt(
    StockTransfer transfer,
    TransferCorrectionDraft draft,
  ) => _run(
    (workflow, session) => workflow.correctReceipt(
      session: session,
      transfer: transfer,
      draft: draft,
    ),
  );

  Future<Result<void, Failure>> cancel(StockTransfer transfer, String reason) =>
      _run(
        (workflow, session) => workflow.cancel(
          session: session,
          transfer: transfer,
          reason: reason,
        ),
      );

  Future<Result<void, Failure>> configurePolicy(TransferPolicy policy) async {
    state = const AsyncLoading();
    final result = await ref.read(configureTransferPolicyUseCaseProvider)(
      session: ref.read(activeTransferSessionProvider),
      policy: policy,
    );
    _finish(result);
    ref.invalidate(transferPolicyProvider);
    return result;
  }

  Future<Result<void, Failure>> _run(
    Future<Result<void, Failure>> Function(
      TransferWorkflowUseCase workflow,
      AuthSession? session,
    )
    action,
  ) async {
    state = const AsyncLoading();
    final result = await action(
      ref.read(transferWorkflowUseCaseProvider),
      ref.read(activeTransferSessionProvider),
    );
    _finish(result);
    return result;
  }

  void _finish<S>(Result<S, Failure> result) {
    state = result.fold(
      onSuccess: (_) => const AsyncData(null),
      onFailure: (failure) =>
          AsyncError(failure, failure.stackTrace ?? StackTrace.current),
    );
  }
}
