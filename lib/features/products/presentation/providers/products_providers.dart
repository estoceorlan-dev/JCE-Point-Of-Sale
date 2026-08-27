import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/remote/firebase_functions_provider.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/data_sources/product_catalog_local_data_source.dart';
import '../../data/repositories/drift_products_repository.dart';
import '../../data/services/product_image_upload_processor.dart';
import '../../domain/entities/catalog_category.dart';
import '../../domain/entities/catalog_tax_category.dart';
import '../../domain/entities/catalog_unit.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';
import '../../domain/entities/product_summary.dart';
import '../../domain/repositories/products_repository.dart';
import '../../domain/use_cases/add_product_price_use_case.dart';
import '../../domain/use_cases/create_category_use_case.dart';
import '../../domain/use_cases/create_product_use_case.dart';
import '../../domain/use_cases/create_unit_use_case.dart';
import '../../domain/use_cases/set_category_archived_use_case.dart';
import '../../domain/use_cases/set_product_archived_use_case.dart';
import '../../domain/use_cases/set_unit_archived_use_case.dart';
import '../../domain/use_cases/update_category_use_case.dart';
import '../../domain/use_cases/update_product_use_case.dart';
import '../../domain/use_cases/update_unit_use_case.dart';
import '../../domain/use_cases/validate_product_use_case.dart';

final productCatalogLocalDataSourceProvider =
    Provider<ProductCatalogLocalDataSource>((ref) {
      return ProductCatalogLocalDataSource(ref.watch(appDatabaseProvider));
    });

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return DriftProductsRepository(
    localDataSource: ref.watch(productCatalogLocalDataSourceProvider),
    localMutationTransaction: ref.watch(localMutationTransactionProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  );
});

final productImageUploadProcessorProvider =
    Provider<ProductImageUploadProcessor>((ref) {
      final config = ref.watch(appConfigProvider);
      return ProductImageUploadProcessor(
        database: ref.watch(appDatabaseProvider),
        firebaseAuth: ref.watch(firebaseAuthProvider),
        storage: FirebaseStorage.instance,
        functions: ref.watch(firebaseFunctionsProvider),
        functionName: config.finalizeProductImageFunctionName,
        idGenerator: ref.watch(idGeneratorProvider),
        clock: ref.watch(appClockProvider),
        logger: ref.watch(appLoggerProvider),
      );
    });

final pendingProductImageUploadProvider = FutureProvider<int>((ref) async {
  final config = ref.watch(appConfigProvider);
  final context = ref.watch(businessContextProvider);
  if (config.enableDemoAuth || context == null) {
    return 0;
  }
  return ref.watch(productImageUploadProcessorProvider).processPending(context);
});

final productPageProvider = StreamProvider.family<ProductPage, ProductQuery>((
  ref,
  query,
) {
  final context = ref.watch(businessContextProvider);
  if (context == null) {
    return Stream.value(const ProductPage(items: [], hasMore: false));
  }
  return ref
      .watch(productsRepositoryProvider)
      .watchProducts(context: context, query: query);
});

final productCategoriesProvider = StreamProvider<List<CatalogCategory>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) {
    return Stream.value(const <CatalogCategory>[]);
  }
  return ref
      .watch(productsRepositoryProvider)
      .watchCategories(context: context);
});

final allProductCategoriesProvider = StreamProvider<List<CatalogCategory>>((
  ref,
) {
  final context = ref.watch(businessContextProvider);
  if (context == null) {
    return Stream.value(const <CatalogCategory>[]);
  }
  return ref
      .watch(productsRepositoryProvider)
      .watchCategories(context: context, includeArchived: true);
});

final productUnitsProvider = StreamProvider<List<CatalogUnit>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) {
    return Stream.value(const <CatalogUnit>[]);
  }
  return ref.watch(productsRepositoryProvider).watchUnits(context: context);
});

final allProductUnitsProvider = StreamProvider<List<CatalogUnit>>((ref) {
  final context = ref.watch(businessContextProvider);
  if (context == null) {
    return Stream.value(const <CatalogUnit>[]);
  }
  return ref
      .watch(productsRepositoryProvider)
      .watchUnits(context: context, includeArchived: true);
});

final productTaxCategoriesProvider = StreamProvider<List<CatalogTaxCategory>>((
  ref,
) {
  final context = ref.watch(businessContextProvider);
  if (context == null) {
    return Stream.value(const <CatalogTaxCategory>[]);
  }
  return ref
      .watch(productsRepositoryProvider)
      .watchTaxCategories(context: context);
});

final productDetailsProvider = FutureProvider.family<Product?, String>((
  ref,
  productId,
) {
  final context = ref.watch(businessContextProvider);
  if (context == null) {
    return Future<Product?>.value();
  }
  return ref
      .watch(productsRepositoryProvider)
      .getProduct(context: context, productId: productId);
});

final validateProductUseCaseProvider = Provider<ValidateProductUseCase>((ref) {
  return const ValidateProductUseCase();
});

final createProductUseCaseProvider = Provider<CreateProductUseCase>((ref) {
  return CreateProductUseCase(
    repository: ref.watch(productsRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
    validateProduct: ref.watch(validateProductUseCaseProvider),
  );
});

final addProductPriceUseCaseProvider = Provider<AddProductPriceUseCase>((ref) {
  return AddProductPriceUseCase(
    repository: ref.watch(productsRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  );
});

final updateProductUseCaseProvider = Provider<UpdateProductUseCase>((ref) {
  return UpdateProductUseCase(
    repository: ref.watch(productsRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
    validateProduct: ref.watch(validateProductUseCaseProvider),
  );
});

final setProductArchivedUseCaseProvider = Provider<SetProductArchivedUseCase>((
  ref,
) {
  return SetProductArchivedUseCase(
    repository: ref.watch(productsRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  );
});

final createCategoryUseCaseProvider = Provider<CreateCategoryUseCase>((ref) {
  return CreateCategoryUseCase(
    repository: ref.watch(productsRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  );
});

final createUnitUseCaseProvider = Provider<CreateUnitUseCase>((ref) {
  return CreateUnitUseCase(
    repository: ref.watch(productsRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  );
});

final updateCategoryUseCaseProvider = Provider<UpdateCategoryUseCase>((ref) {
  return UpdateCategoryUseCase(
    repository: ref.watch(productsRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  );
});

final setCategoryArchivedUseCaseProvider = Provider<SetCategoryArchivedUseCase>(
  (ref) {
    return SetCategoryArchivedUseCase(
      repository: ref.watch(productsRepositoryProvider),
      requirePermission: ref.watch(requirePermissionUseCaseProvider),
    );
  },
);

final updateUnitUseCaseProvider = Provider<UpdateUnitUseCase>((ref) {
  return UpdateUnitUseCase(
    repository: ref.watch(productsRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  );
});

final setUnitArchivedUseCaseProvider = Provider<SetUnitArchivedUseCase>((ref) {
  return SetUnitArchivedUseCase(
    repository: ref.watch(productsRepositoryProvider),
    requirePermission: ref.watch(requirePermissionUseCaseProvider),
  );
});

final activeProductSessionProvider = Provider((ref) {
  return ref.watch(authControllerProvider).asData?.value;
});
