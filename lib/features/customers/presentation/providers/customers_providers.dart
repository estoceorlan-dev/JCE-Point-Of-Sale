import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/data_sources/customers_local_data_source.dart';
import '../../data/repositories/drift_customers_repository.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customers_repository.dart';
import '../../domain/use_cases/add_customer_note_use_case.dart';
import '../../domain/use_cases/adjust_loyalty_points_use_case.dart';
import '../../domain/use_cases/anonymize_customer_use_case.dart';
import '../../domain/use_cases/create_customer_use_case.dart';
import '../../domain/use_cases/customer_lifecycle_use_case.dart';
import '../../domain/use_cases/merge_customers_use_case.dart';
import '../../domain/use_cases/update_customer_use_case.dart';

typedef CustomerDirectoryQuery = ({String search, bool includeInactive});

final customersLocalDataSourceProvider = Provider<CustomersLocalDataSource>(
  (ref) => CustomersLocalDataSource(ref.watch(appDatabaseProvider)),
);

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return DriftCustomersRepository(
    database: ref.watch(appDatabaseProvider),
    localDataSource: ref.watch(customersLocalDataSourceProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final customerDirectoryProvider =
    StreamProvider.family<List<CustomerSummary>, CustomerDirectoryQuery>((
      ref,
      query,
    ) {
      final context = ref.watch(businessContextProvider);
      if (context == null) return Stream.value(const []);
      return ref
          .watch(customersRepositoryProvider)
          .watchCustomers(
            context: context,
            search: query.search,
            includeInactive: query.includeInactive,
          );
    });

final customerProfileProvider = StreamProvider.family<CustomerProfile?, String>(
  (ref, customerId) {
    final context = ref.watch(businessContextProvider);
    if (context == null) return Stream.value(null);
    return ref
        .watch(customersRepositoryProvider)
        .watchCustomerProfile(context: context, customerId: customerId);
  },
);

final selectedCheckoutCustomerProvider = StateProvider<CustomerSummary?>(
  (ref) => null,
);

final createCustomerUseCaseProvider = Provider<CreateCustomerUseCase>(
  (ref) => CreateCustomerUseCase(
    repository: ref.watch(customersRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final updateCustomerUseCaseProvider = Provider<UpdateCustomerUseCase>(
  (ref) => UpdateCustomerUseCase(
    repository: ref.watch(customersRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final customerLifecycleUseCaseProvider = Provider<CustomerLifecycleUseCase>(
  (ref) => CustomerLifecycleUseCase(
    repository: ref.watch(customersRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final mergeCustomersUseCaseProvider = Provider<MergeCustomersUseCase>(
  (ref) => MergeCustomersUseCase(
    repository: ref.watch(customersRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final anonymizeCustomerUseCaseProvider = Provider<AnonymizeCustomerUseCase>(
  (ref) => AnonymizeCustomerUseCase(
    repository: ref.watch(customersRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final addCustomerNoteUseCaseProvider = Provider<AddCustomerNoteUseCase>(
  (ref) => AddCustomerNoteUseCase(
    repository: ref.watch(customersRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final adjustLoyaltyPointsUseCaseProvider = Provider<AdjustLoyaltyPointsUseCase>(
  (ref) => AdjustLoyaltyPointsUseCase(
    repository: ref.watch(customersRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final activeCustomerSessionProvider = Provider(
  (ref) => ref.watch(authControllerProvider).asData?.value,
);
