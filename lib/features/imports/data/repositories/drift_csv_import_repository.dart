import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/business_context.dart';
import '../../../inventory/domain/entities/inventory_movement.dart';
import '../../../inventory/domain/entities/inventory_transaction_type.dart';
import '../../../inventory/domain/repositories/inventory_repository.dart';
import '../../../products/domain/repositories/products_repository.dart';
import '../../domain/entities/csv_import.dart';
import '../../domain/repositories/csv_import_repository.dart';
import '../services/csv_import_preparer.dart';

class DriftCsvImportRepository implements CsvImportRepository {
  const DriftCsvImportRepository({
    required this.database,
    required this.clock,
    required this.productsFactory,
    required this.inventoryFactory,
  });
  final AppDatabase database;
  final AppClock clock;
  final ProductsRepository Function(IdGenerator) productsFactory;
  final InventoryRepository Function(IdGenerator) inventoryFactory;

  @override
  Future<Result<CsvImportPreview, Failure>> preview({
    required BusinessContext context,
    required CsvImportKind kind,
    required String source,
  }) async {
    try {
      return Result.success(
        (await CsvImportPreparer(
          database,
        ).prepare(context, kind, source)).preview,
      );
    } catch (error, stack) {
      return Result.failure(_failure(error, stack));
    }
  }

  @override
  Future<Result<int, Failure>> confirm({
    required BusinessContext context,
    required CsvImportPreview preview,
  }) async {
    final batchId = const Uuid().v5(
      Namespace.url.value,
      '${context.organizationId}:${context.branchId}:${preview.kind.name}:${preview.source}',
    );
    try {
      final count = await database.transaction(() async {
        final marker = 'csv_import:$batchId';
        if (await database.metadataDao.readValue(marker) != null) return 0;
        final prepared = await CsvImportPreparer(
          database,
        ).prepare(context, preview.kind, preview.source);
        if (!prepared.preview.canConfirm) {
          throw const ValidationFailure(
            'Import data changed. Preview and correct the errors again.',
          );
        }
        if (prepared.preview.revision != preview.revision) {
          throw const ConflictFailure(
            'Catalog data changed after preview. Preview the file again.',
          );
        }
        for (final row in prepared.rows) {
          final ids = _ImportIds('$batchId:${row.summary.number}');
          if (preview.kind == CsvImportKind.catalog) {
            final repository = productsFactory(ids);
            final result = row.productId == null
                ? await repository.createProduct(
                    context: context,
                    draft: row.draft!,
                  )
                : await repository.updateProduct(
                    context: context,
                    productId: row.productId!,
                    draft: row.draft!,
                  );
            if (result.failureOrNull case final failure?) throw failure;
          } else {
            final result = await inventoryFactory(ids).postMovement(
              context: context,
              draft: InventoryMovementDraft(
                type: InventoryTransactionType.openingBalance,
                operationId: ids.newId(),
                reasonCode: 'opening_stock_import',
                referenceType: 'csv_import',
                referenceId: batchId,
                lines: [
                  InventoryMovementLineDraft(
                    stockLocationId: row.locationId!,
                    productId: row.productId!,
                    quantityDeltaMilli: row.quantityMilli!,
                    expectedBalanceVersion: 0,
                  ),
                ],
              ),
            );
            if (result.failureOrNull case final failure?) throw failure;
          }
        }
        await database.metadataDao.writeValue(
          key: marker,
          value: prepared.rows.length.toString(),
          updatedAt: clock.nowUtc(),
        );
        return prepared.rows.length;
      });
      return Result.success(count);
    } catch (error, stack) {
      return Result.failure(_failure(error, stack));
    }
  }

  Failure _failure(Object error, StackTrace stack) => error is Failure
      ? error
      : error is FormatException
      ? ValidationFailure(error.message)
      : FailureMapper.fromException(error, stack);
}

class _ImportIds implements IdGenerator {
  _ImportIds(this.seed);
  final String seed;
  int _sequence = 0;
  @override
  String newId() =>
      const Uuid().v5(Namespace.url.value, '$seed:${_sequence++}');
}
