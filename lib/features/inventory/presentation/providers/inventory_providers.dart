import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/data_sources/inventory_local_data_source.dart';
import '../../data/repositories/drift_inventory_repository.dart';
import '../../domain/entities/inventory_adjustment.dart';
import '../../domain/entities/inventory_balance.dart';
import '../../domain/entities/inventory_movement.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_location.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/use_cases/cancel_stock_count_use_case.dart';
import '../../domain/use_cases/complete_stock_count_use_case.dart';
import '../../domain/use_cases/configure_inventory_policy_use_case.dart';
import '../../domain/use_cases/create_inventory_adjustment_use_case.dart';
import '../../domain/use_cases/create_stock_location_use_case.dart';
import '../../domain/use_cases/record_stock_count_item_use_case.dart';
import '../../domain/use_cases/reverse_inventory_movement_use_case.dart';
import '../../domain/use_cases/set_reorder_point_use_case.dart';
import '../../domain/use_cases/start_stock_count_use_case.dart';

final inventoryLocalDataSourceProvider = Provider<InventoryLocalDataSource>((
  ref,
) {
  return InventoryLocalDataSource(ref.watch(appDatabaseProvider));
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return DriftInventoryRepository(
    database: ref.watch(appDatabaseProvider),
    localDataSource: ref.watch(inventoryLocalDataSourceProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final stockLocationsProvider = StreamProvider<List<StockLocation>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref
      .watch(inventoryRepositoryProvider)
      .watchStockLocations(context: context);
});

final inventoryBalancesProvider =
    StreamProvider.family<List<InventoryBalance>, InventoryBalanceQuery>((
      ref,
      query,
    ) {
      final context = ref.watch(businessContextProvider);
      if (context == null) return Stream.value(const []);
      return ref
          .watch(inventoryRepositoryProvider)
          .watchBalances(context: context, query: query);
    });

final inventoryMovementsProvider =
    StreamProvider.family<List<InventoryMovement>, InventoryMovementFilter>((
      ref,
      filter,
    ) {
      final context = ref.watch(businessContextProvider);
      if (context == null) return Stream.value(const []);
      return ref
          .watch(inventoryRepositoryProvider)
          .watchMovements(context: context, filter: filter);
    });

final stockCountsProvider = StreamProvider<List<StockCount>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref
      .watch(inventoryRepositoryProvider)
      .watchStockCounts(context: context);
});

final inventoryPolicyProvider = FutureProvider<InventoryPolicy?>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Future.value();
  return ref.watch(inventoryRepositoryProvider).getPolicy(context: context);
});

final createStockLocationUseCaseProvider = Provider<CreateStockLocationUseCase>(
  (ref) => CreateStockLocationUseCase(
    repository: ref.watch(inventoryRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final createInventoryAdjustmentUseCaseProvider =
    Provider<CreateInventoryAdjustmentUseCase>(
      (ref) => CreateInventoryAdjustmentUseCase(
        repository: ref.watch(inventoryRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final reverseInventoryMovementUseCaseProvider =
    Provider<ReverseInventoryMovementUseCase>(
      (ref) => ReverseInventoryMovementUseCase(
        repository: ref.watch(inventoryRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final setReorderPointUseCaseProvider = Provider<SetReorderPointUseCase>(
  (ref) => SetReorderPointUseCase(
    repository: ref.watch(inventoryRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final configureInventoryPolicyUseCaseProvider =
    Provider<ConfigureInventoryPolicyUseCase>(
      (ref) => ConfigureInventoryPolicyUseCase(
        repository: ref.watch(inventoryRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final startStockCountUseCaseProvider = Provider<StartStockCountUseCase>(
  (ref) => StartStockCountUseCase(
    repository: ref.watch(inventoryRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final recordStockCountItemUseCaseProvider =
    Provider<RecordStockCountItemUseCase>(
      (ref) => RecordStockCountItemUseCase(
        repository: ref.watch(inventoryRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final completeStockCountUseCaseProvider = Provider<CompleteStockCountUseCase>(
  (ref) => CompleteStockCountUseCase(
    repository: ref.watch(inventoryRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final cancelStockCountUseCaseProvider = Provider<CancelStockCountUseCase>(
  (ref) => CancelStockCountUseCase(
    repository: ref.watch(inventoryRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final activeInventorySessionProvider = Provider((ref) {
  return ref.watch(authControllerProvider).asData?.value;
});
