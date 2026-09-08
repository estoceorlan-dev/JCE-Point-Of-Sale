import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/inventory_adjustment.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_location.dart';
import '../providers/inventory_providers.dart';

final inventoryMutationControllerProvider =
    AsyncNotifierProvider<InventoryMutationController, void>(
      InventoryMutationController.new,
    );

class InventoryMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<void, Failure>> updateLocation(
    StockLocation location,
    StockLocationDraft draft,
  ) async {
    state = const AsyncLoading();
    final result = await ref.read(updateStockLocationUseCaseProvider)(
      session: ref.read(activeInventorySessionProvider),
      location: location,
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> setLocationArchived(
    StockLocation location,
    bool archived,
  ) async {
    state = const AsyncLoading();
    final result = await ref.read(setStockLocationArchivedUseCaseProvider)(
      session: ref.read(activeInventorySessionProvider),
      location: location,
      archived: archived,
    );
    _finish(result);
    return result;
  }

  Future<Result<String, Failure>> createLocation(
    StockLocationDraft draft,
  ) async {
    state = const AsyncLoading();
    final result = await ref.read(createStockLocationUseCaseProvider)(
      session: ref.read(activeInventorySessionProvider),
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<String, Failure>> createAdjustment(
    InventoryAdjustmentDraft draft, {
    bool approveAsManager = false,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(createInventoryAdjustmentUseCaseProvider)(
      session: ref.read(activeInventorySessionProvider),
      draft: draft,
      approveAsManager: approveAsManager,
    );
    _finish(result);
    return result;
  }

  Future<Result<String, Failure>> reverseMovement({
    required String transactionId,
    required String reason,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(reverseInventoryMovementUseCaseProvider)(
      session: ref.read(activeInventorySessionProvider),
      transactionId: transactionId,
      reason: reason,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> setReorderPoint({
    required String stockLocationId,
    required String productId,
    required int reorderPointMilli,
    required int expectedVersion,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(setReorderPointUseCaseProvider)(
      session: ref.read(activeInventorySessionProvider),
      stockLocationId: stockLocationId,
      productId: productId,
      reorderPointMilli: reorderPointMilli,
      expectedVersion: expectedVersion,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> configurePolicy(InventoryPolicy policy) async {
    state = const AsyncLoading();
    final result = await ref.read(configureInventoryPolicyUseCaseProvider)(
      session: ref.read(activeInventorySessionProvider),
      policy: policy,
    );
    _finish(result);
    ref.invalidate(inventoryPolicyProvider);
    return result;
  }

  Future<Result<String, Failure>> startCount(StartStockCountDraft draft) async {
    state = const AsyncLoading();
    final result = await ref.read(startStockCountUseCaseProvider)(
      session: ref.read(activeInventorySessionProvider),
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> recordCount({
    required String stockCountId,
    required String itemId,
    required int countedQuantityMilli,
    required int expectedVersion,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(recordStockCountItemUseCaseProvider)(
      session: ref.read(activeInventorySessionProvider),
      stockCountId: stockCountId,
      itemId: itemId,
      countedQuantityMilli: countedQuantityMilli,
      expectedVersion: expectedVersion,
    );
    _finish(result);
    return result;
  }

  Future<Result<String?, Failure>> completeCount(StockCount count) async {
    state = const AsyncLoading();
    final result = await ref.read(completeStockCountUseCaseProvider)(
      session: ref.read(activeInventorySessionProvider),
      stockCountId: count.id,
      expectedVersion: count.version,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> cancelCount(StockCount count) async {
    state = const AsyncLoading();
    final result = await ref.read(cancelStockCountUseCaseProvider)(
      session: ref.read(activeInventorySessionProvider),
      stockCountId: count.id,
      expectedVersion: count.version,
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
