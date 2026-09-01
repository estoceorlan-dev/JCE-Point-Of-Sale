import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/goods_receipt.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/supplier.dart';
import '../providers/purchases_providers.dart';

final purchaseMutationControllerProvider =
    AsyncNotifierProvider<PurchaseMutationController, void>(
      PurchaseMutationController.new,
    );

class PurchaseMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<String, Failure>> createSupplier(SupplierDraft draft) async {
    state = const AsyncLoading();
    final result = await ref
        .read(manageSupplierUseCaseProvider)
        .create(session: ref.read(activePurchaseSessionProvider), draft: draft);
    _finish(result);
    ref.invalidate(purchaseOptionsProvider);
    return result;
  }

  Future<Result<void, Failure>> archiveSupplier(Supplier supplier) => _runVoid(
    () => ref
        .read(manageSupplierUseCaseProvider)
        .archive(
          session: ref.read(activePurchaseSessionProvider),
          supplier: supplier,
        ),
  );

  Future<Result<String, Failure>> createOrder(PurchaseOrderDraft draft) async {
    state = const AsyncLoading();
    final result = await ref.read(createPurchaseOrderUseCaseProvider)(
      session: ref.read(activePurchaseSessionProvider),
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> submit(PurchaseOrder order) => _runVoid(
    () => ref
        .read(purchaseOrderWorkflowUseCaseProvider)
        .submit(session: ref.read(activePurchaseSessionProvider), order: order),
  );

  Future<Result<void, Failure>> approve(PurchaseOrder order) => _runVoid(
    () => ref
        .read(purchaseOrderWorkflowUseCaseProvider)
        .approve(
          session: ref.read(activePurchaseSessionProvider),
          order: order,
        ),
  );

  Future<Result<void, Failure>> cancel(PurchaseOrder order, String reason) =>
      _runVoid(
        () => ref
            .read(purchaseOrderWorkflowUseCaseProvider)
            .cancel(
              session: ref.read(activePurchaseSessionProvider),
              order: order,
              reason: reason,
            ),
      );

  Future<Result<String, Failure>> receive(
    PurchaseOrder order,
    GoodsReceiptDraft draft,
  ) async {
    state = const AsyncLoading();
    final result = await ref
        .read(purchaseOrderWorkflowUseCaseProvider)
        .receive(
          session: ref.read(activePurchaseSessionProvider),
          order: order,
          draft: draft,
        );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> _runVoid(
    Future<Result<void, Failure>> Function() operation,
  ) async {
    state = const AsyncLoading();
    final result = await operation();
    _finish(result);
    return result;
  }

  void _finish<T>(Result<T, Failure> result) {
    state = result.fold(
      onSuccess: (_) => const AsyncData(null),
      onFailure: (failure) =>
          AsyncError(failure, failure.stackTrace ?? StackTrace.current),
    );
  }
}
