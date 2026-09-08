import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/inventory_adjustment.dart';
import '../entities/inventory_balance.dart';
import '../entities/inventory_movement.dart';
import '../entities/stock_count.dart';
import '../entities/stock_location.dart';

abstract interface class InventoryRepository {
  Stream<List<StockLocation>> watchStockLocations({
    required BusinessContext context,
    bool includeArchived = false,
  });

  Future<Result<void, Failure>> updateStockLocation({
    required BusinessContext context,
    required String locationId,
    required StockLocationDraft draft,
    required int expectedVersion,
  });

  Future<Result<void, Failure>> setStockLocationArchived({
    required BusinessContext context,
    required String locationId,
    required bool archived,
    required int expectedVersion,
  });

  Future<Result<String, Failure>> createStockLocation({
    required BusinessContext context,
    required StockLocationDraft draft,
  });

  Stream<List<InventoryBalance>> watchBalances({
    required BusinessContext context,
    InventoryBalanceQuery query = const InventoryBalanceQuery(),
  });

  Stream<List<InventoryMovement>> watchMovements({
    required BusinessContext context,
    InventoryMovementFilter filter = const InventoryMovementFilter(),
  });

  Future<Result<String, Failure>> postMovement({
    required BusinessContext context,
    required InventoryMovementDraft draft,
  });

  Future<Result<String, Failure>> createAdjustment({
    required BusinessContext context,
    required InventoryAdjustmentDraft draft,
    String? approvedByUserId,
  });

  Future<Result<String, Failure>> reverseMovement({
    required BusinessContext context,
    required String transactionId,
    required String reason,
    String? operationId,
  });

  Future<Result<void, Failure>> setReorderPoint({
    required BusinessContext context,
    required String stockLocationId,
    required String productId,
    required int reorderPointMilli,
    required int expectedVersion,
  });

  Future<InventoryPolicy?> getPolicy({required BusinessContext context});

  Future<Result<void, Failure>> configurePolicy({
    required BusinessContext context,
    required InventoryPolicy policy,
  });

  Stream<List<StockCount>> watchStockCounts({required BusinessContext context});

  Future<Result<String, Failure>> startStockCount({
    required BusinessContext context,
    required StartStockCountDraft draft,
  });

  Future<Result<void, Failure>> recordCountedQuantity({
    required BusinessContext context,
    required String stockCountId,
    required String itemId,
    required int countedQuantityMilli,
    required int expectedVersion,
  });

  Future<Result<String?, Failure>> completeStockCount({
    required BusinessContext context,
    required String stockCountId,
    required int expectedVersion,
    String? operationId,
  });

  Future<Result<void, Failure>> cancelStockCount({
    required BusinessContext context,
    required String stockCountId,
    required int expectedVersion,
  });
}
