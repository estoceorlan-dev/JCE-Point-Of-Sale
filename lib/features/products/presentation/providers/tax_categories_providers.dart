import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../data/repositories/drift_tax_categories_repository.dart';
import '../../domain/entities/catalog_tax_category.dart';
import '../../domain/repositories/tax_categories_repository.dart';
import '../../domain/use_cases/manage_tax_category_use_case.dart';
import 'products_providers.dart';

final taxCategoriesRepositoryProvider = Provider<TaxCategoriesRepository>(
  (ref) => DriftTaxCategoriesRepository(
    database: ref.watch(appDatabaseProvider),
    ids: ref.watch(idGeneratorProvider),
    clock: ref.watch(appClockProvider),
  ),
);

final manageTaxCategoryUseCaseProvider = Provider<ManageTaxCategoryUseCase>(
  (ref) => ManageTaxCategoryUseCase(ref.watch(taxCategoriesRepositoryProvider)),
);

final allTaxCategoriesProvider = StreamProvider<List<CatalogTaxCategory>>((
  ref,
) {
  final context = ref.watch(businessContextProvider);
  return context == null
      ? Stream.value(const [])
      : ref
            .watch(productsRepositoryProvider)
            .watchTaxCategories(context: context, includeArchived: true);
});
