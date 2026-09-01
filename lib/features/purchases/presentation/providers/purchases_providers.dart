import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/data_sources/purchases_local_data_source.dart';
import '../../data/repositories/drift_purchases_repository.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/purchases_repository.dart';
import '../../domain/use_cases/create_purchase_order_use_case.dart';
import '../../domain/use_cases/manage_supplier_use_case.dart';
import '../../domain/use_cases/purchase_order_workflow_use_case.dart';

final purchasesLocalDataSourceProvider = Provider<PurchasesLocalDataSource>(
  (ref) => PurchasesLocalDataSource(ref.watch(appDatabaseProvider)),
);

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return DriftPurchasesRepository(
    database: ref.watch(appDatabaseProvider),
    localDataSource: ref.watch(purchasesLocalDataSourceProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final suppliersProvider = StreamProvider<List<Supplier>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref
      .watch(purchasesRepositoryProvider)
      .watchSuppliers(context: context);
});

final purchaseOrdersProvider = StreamProvider<List<PurchaseOrder>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref
      .watch(purchasesRepositoryProvider)
      .watchPurchaseOrders(context: context);
});

final purchaseOptionsProvider = FutureProvider<PurchaseOptions>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) {
    return Future.value(
      const PurchaseOptions(suppliers: [], products: [], locations: []),
    );
  }
  return ref.watch(purchasesRepositoryProvider).getOptions(context: context);
});

final manageSupplierUseCaseProvider = Provider<ManageSupplierUseCase>(
  (ref) => ManageSupplierUseCase(
    repository: ref.watch(purchasesRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final createPurchaseOrderUseCaseProvider = Provider<CreatePurchaseOrderUseCase>(
  (ref) => CreatePurchaseOrderUseCase(
    repository: ref.watch(purchasesRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final purchaseOrderWorkflowUseCaseProvider =
    Provider<PurchaseOrderWorkflowUseCase>(
      (ref) => PurchaseOrderWorkflowUseCase(
        repository: ref.watch(purchasesRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final activePurchaseSessionProvider = Provider(
  (ref) => ref.watch(authControllerProvider).asData?.value,
);
