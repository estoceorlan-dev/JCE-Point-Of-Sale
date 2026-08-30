import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/data_sources/sales_local_data_source.dart';
import '../../data/repositories/drift_sales_repository.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_product.dart';
import '../../domain/entities/sale_correction.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/services/receipt_renderer.dart';
import '../../domain/use_cases/checkout_sale_use_case.dart';
import '../../domain/use_cases/configure_discount_policy_use_case.dart';
import '../../domain/use_cases/configure_correction_policy_use_case.dart';
import '../../domain/use_cases/correct_sale_use_case.dart';

final salesLocalDataSourceProvider = Provider<SalesLocalDataSource>((ref) {
  return SalesLocalDataSource(ref.watch(appDatabaseProvider));
});

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return DriftSalesRepository(
    database: ref.watch(appDatabaseProvider),
    localDataSource: ref.watch(salesLocalDataSourceProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final saleProductSearchProvider =
    StreamProvider.family<List<SaleProduct>, String>((ref, search) {
      final context = ref.watch(businessContextProvider);
      if (context == null) return Stream.value(const []);
      return ref
          .watch(salesRepositoryProvider)
          .watchSaleProducts(context: context, search: search);
    });

final recentSalesProvider = StreamProvider<List<SaleRecord>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Stream.value(const []);
  return ref.watch(salesRepositoryProvider).watchRecentSales(context: context);
});

final saleDetailsProvider = FutureProvider.family<SaleRecord?, String>((
  ref,
  saleId,
) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Future.value();
  return ref
      .watch(salesRepositoryProvider)
      .getSale(context: context, saleId: saleId);
});

final discountPolicyProvider = FutureProvider<DiscountPolicy?>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Future.value();
  return ref.watch(salesRepositoryProvider).getDiscountPolicy(context: context);
});

final correctionPolicyProvider = FutureProvider<SaleCorrectionPolicy?>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Future.value();
  return ref
      .watch(salesRepositoryProvider)
      .getCorrectionPolicy(context: context);
});

final returnDestinationsProvider = FutureProvider<List<ReturnDestination>>((
  ref,
) {
  final context = ref.watch(businessContextProvider);
  if (context == null) return Future.value(const []);
  return ref
      .watch(salesRepositoryProvider)
      .getReturnDestinations(context: context);
});

final receiptRendererProvider = Provider<ReceiptRenderer>(
  (ref) => const PlainTextReceiptRenderer(),
);

final correctionReceiptRendererProvider = Provider<CorrectionReceiptRenderer>(
  (ref) => const PlainTextCorrectionReceiptRenderer(),
);

final checkoutSaleUseCaseProvider = Provider<CheckoutSaleUseCase>(
  (ref) => CheckoutSaleUseCase(
    repository: ref.watch(salesRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final configureDiscountPolicyUseCaseProvider =
    Provider<ConfigureDiscountPolicyUseCase>(
      (ref) => ConfigureDiscountPolicyUseCase(
        repository: ref.watch(salesRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final correctSaleUseCaseProvider = Provider<CorrectSaleUseCase>(
  (ref) => CorrectSaleUseCase(
    repository: ref.watch(salesRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  ),
);

final configureCorrectionPolicyUseCaseProvider =
    Provider<ConfigureCorrectionPolicyUseCase>(
      (ref) => ConfigureCorrectionPolicyUseCase(
        repository: ref.watch(salesRepositoryProvider),
        requirePermission: ref.watch(requirePermissionUseCaseProvider),
      ),
    );

final activePosSessionProvider = Provider((ref) {
  return ref.watch(authControllerProvider).asData?.value;
});
