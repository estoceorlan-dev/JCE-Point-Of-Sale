import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../inventory/data/data_sources/inventory_local_data_source.dart';
import '../../../inventory/data/repositories/drift_inventory_repository.dart';
import '../../../products/data/data_sources/product_catalog_local_data_source.dart';
import '../../../products/data/repositories/drift_products_repository.dart';
import '../../data/repositories/drift_csv_import_repository.dart';
import '../../data/services/platform_csv_file_service.dart';
import '../../domain/repositories/csv_import_repository.dart';
import '../../domain/services/csv_file_service.dart';
import '../../domain/use_cases/import_csv_use_case.dart';

final csvFileServiceProvider = Provider<CsvFileService>(
  (ref) => const PlatformCsvFileService(),
);
final csvImportRepositoryProvider = Provider<CsvImportRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final clock = ref.watch(appClockProvider);
  final transaction = ref.watch(localMutationTransactionProvider);
  return DriftCsvImportRepository(
    database: database,
    clock: clock,
    productsFactory: (ids) => DriftProductsRepository(
      localDataSource: ProductCatalogLocalDataSource(database),
      localMutationTransaction: transaction,
      idGenerator: ids,
      clock: clock,
    ),
    inventoryFactory: (ids) => DriftInventoryRepository(
      database: database,
      localDataSource: InventoryLocalDataSource(database),
      localMutationTransaction: transaction,
      idGenerator: ids,
      clock: clock,
    ),
  );
});
final importCsvUseCaseProvider = Provider<ImportCsvUseCase>(
  (ref) => ImportCsvUseCase(ref.watch(csvImportRepositoryProvider)),
);
