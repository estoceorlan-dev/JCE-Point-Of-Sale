import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jce_pos/core/database/app_database.dart';
import 'package:jce_pos/core/database/local_mutation_transaction.dart';
import 'package:jce_pos/core/error/failures.dart';
import 'package:jce_pos/core/utils/app_clock.dart';
import 'package:jce_pos/core/utils/id_generator.dart';
import 'package:jce_pos/features/inventory/data/data_sources/inventory_local_data_source.dart';
import 'package:jce_pos/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:jce_pos/features/inventory/domain/entities/stock_location.dart'
    as domain;
import 'package:jce_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:jce_pos/features/inventory/domain/entities/inventory_transaction_type.dart';
import 'package:jce_pos/features/inventory/domain/entities/stock_count.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  late AppDatabase database;
  late DriftInventoryRepository repository;
  final now = DateTime.utc(2026, 9, 7);
  const context = BusinessContext(
    organizationId: 'organization',
    branchId: 'branch',
    actorUserId: 'app-user',
  );
  Future<void> acknowledge() async {
    await database
        .update(database.syncOutboxEntries)
        .write(const SyncOutboxEntriesCompanion(status: Value('succeeded')));
  }

  Future<StockLocation> location(String id) => (database.select(
    database.stockLocations,
  )..where((row) => row.id.equals(id))).getSingle();
  Future<String> create({
    String code = 'SECOND',
    bool isDefault = false,
  }) async {
    final result = await repository.createStockLocation(
      context: context,
      draft: domain.StockLocationDraft(
        code: code,
        name: 'Second warehouse',
        isDefault: isDefault,
      ),
    );
    expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
    return result.valueOrNull!;
  }

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftInventoryRepository(
      database: database,
      localDataSource: InventoryLocalDataSource(database),
      localMutationTransaction: LocalMutationTransaction(database),
      idGenerator: _SequenceIdGenerator(),
      clock: FixedAppClock(now),
    );
    await _seedInventoryContext(database);
  });
  tearDown(() => database.close());

  test(
    'edit archive restore preserve identity and append audit/outbox with versions',
    () async {
      final id = await create();
      await acknowledge();
      final edited = await repository.updateStockLocation(
        context: context,
        locationId: id,
        expectedVersion: 0,
        draft: const domain.StockLocationDraft(
          code: 'SECOND',
          name: 'Renamed warehouse',
        ),
      );
      expect(edited.isSuccess, isTrue);
      expect((await location(id)).version, 1);
      await acknowledge();
      expect(
        (await repository.setStockLocationArchived(
          context: context,
          locationId: id,
          archived: true,
          expectedVersion: 1,
        )).isSuccess,
        isTrue,
      );
      expect(
        (await repository.watchStockLocations(context: context).first).map(
          (row) => row.id,
        ),
        isNot(contains(id)),
      );
      expect(
        (await repository
                .watchStockLocations(context: context, includeArchived: true)
                .first)
            .map((row) => row.id),
        contains(id),
      );
      await acknowledge();
      expect(
        (await repository.setStockLocationArchived(
          context: context,
          locationId: id,
          archived: false,
          expectedVersion: 2,
        )).isSuccess,
        isTrue,
      );
      expect((await location(id)).version, 3);
      expect((await location(id)).name, 'Renamed warehouse');
      expect(
        await database.select(database.localAuditLogs).get(),
        hasLength(4),
      );
      expect(
        await database.select(database.syncOutboxEntries).get(),
        hasLength(4),
      );
      expect(
        await database.select(database.inventoryLedgerEntries).get(),
        isEmpty,
      );
    },
  );

  test(
    'stale, foreign, default and pending-operation guards roll back all mutations',
    () async {
      final id = await create();
      expect(
        (await repository.setStockLocationArchived(
          context: context,
          locationId: id,
          archived: true,
          expectedVersion: 0,
        )).failureOrNull,
        isA<ConflictFailure>(),
      );
      await acknowledge();
      expect(
        (await repository.setStockLocationArchived(
          context: context,
          locationId: id,
          archived: true,
          expectedVersion: 4,
        )).failureOrNull,
        isA<ConflictFailure>(),
      );
      expect(
        (await repository.setStockLocationArchived(
          context: context,
          locationId: 'foreign',
          archived: true,
          expectedVersion: 0,
        )).failureOrNull,
        isA<AuthorizationFailure>(),
      );
      expect(
        (await repository.setStockLocationArchived(
          context: context,
          locationId: 'location',
          archived: true,
          expectedVersion: 0,
        )).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        await database.select(database.syncOutboxEntries).get(),
        hasLength(1),
      );
      expect((await location(id)).version, 0);
    },
  );

  test(
    'nonzero stock blocks archive; net zero history survives archive',
    () async {
      final id = await create();
      Future<void> move(String operation, int quantity) async {
        final result = await repository.postMovement(
          context: context,
          draft: InventoryMovementDraft(
            operationId: operation,
            type: quantity > 0
                ? InventoryTransactionType.adjustmentIncrease
                : InventoryTransactionType.adjustmentDecrease,
            lines: [
              InventoryMovementLineDraft(
                stockLocationId: id,
                productId: 'product-a',
                quantityDeltaMilli: quantity,
              ),
            ],
          ),
        );
        expect(result.isSuccess, isTrue, reason: result.failureOrNull?.message);
        await acknowledge();
      }

      await move('add', 1000);
      expect(
        (await repository.setStockLocationArchived(
          context: context,
          locationId: id,
          archived: true,
          expectedVersion: 0,
        )).failureOrNull,
        isA<ValidationFailure>(),
      );
      await move('remove', -1000);
      expect(
        (await repository.setStockLocationArchived(
          context: context,
          locationId: id,
          archived: true,
          expectedVersion: 0,
        )).isSuccess,
        isTrue,
      );
      expect(
        await database.select(database.inventoryLedgerEntries).get(),
        hasLength(2),
      );
      expect(
        (await repository.watchMovements(context: context).first),
        hasLength(2),
      );
      final rejected = await repository.postMovement(
        context: context,
        draft: InventoryMovementDraft(
          operationId: 'archived-add',
          type: InventoryTransactionType.adjustmentIncrease,
          lines: [
            InventoryMovementLineDraft(
              stockLocationId: id,
              productId: 'product-a',
              quantityDeltaMilli: 1000,
            ),
          ],
        ),
      );
      expect(rejected.isFailure, isTrue);
      expect(
        await database.select(database.inventoryLedgerEntries).get(),
        hasLength(2),
      );
    },
  );

  test('open count blocks archive and type changes', () async {
    final id = await create();
    final count = await repository.startStockCount(
      context: context,
      draft: StartStockCountDraft(
        stockLocationId: id,
        type: StockCountType.cycle,
        productIds: const ['product-a'],
      ),
    );
    expect(count.isSuccess, isTrue);
    await acknowledge();
    expect(
      (await repository.setStockLocationArchived(
        context: context,
        locationId: id,
        archived: true,
        expectedVersion: 0,
      )).failureOrNull,
      isA<ValidationFailure>(),
    );
    expect(
      (await repository.updateStockLocation(
        context: context,
        locationId: id,
        expectedVersion: 0,
        draft: const domain.StockLocationDraft(
          code: 'SECOND',
          name: 'Damaged',
          type: domain.StockLocationType.damaged,
        ),
      )).failureOrNull,
      isA<ValidationFailure>(),
    );
  });

  test(
    'normalized collisions include archived records and default changes version both rows',
    () async {
      final id = await create(isDefault: true);
      expect((await location('location')).isDefault, isFalse);
      expect((await location('location')).version, 1);
      expect((await location(id)).isDefault, isTrue);
      await acknowledge();
      expect(
        (await repository.setStockLocationArchived(
          context: context,
          locationId: 'location',
          archived: true,
          expectedVersion: 1,
        )).isSuccess,
        isTrue,
      );
      await acknowledge();
      final duplicate = await repository.createStockLocation(
        context: context,
        draft: const domain.StockLocationDraft(
          code: ' warehouse ',
          name: 'Duplicate',
        ),
      );
      expect(duplicate.failureOrNull, isA<ConflictFailure>());
      expect(
        await database.select(database.stockLocations).get(),
        hasLength(2),
      );
    },
  );
}

Future<void> _seedInventoryContext(AppDatabase database) async {
  final now = DateTime.utc(2026, 8, 24);
  await database
      .into(database.organizations)
      .insert(
        OrganizationsCompanion.insert(
          id: 'organization',
          code: 'JCE',
          name: 'JCE',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.branches)
      .insert(
        BranchesCompanion.insert(
          id: 'branch',
          organizationId: 'organization',
          code: 'MAIN',
          name: 'Main Branch',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.units)
      .insert(
        UnitsCompanion.insert(
          id: 'unit',
          organizationId: 'organization',
          code: 'PC',
          name: 'Piece',
          abbreviation: 'pc',
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (final product in const [
    ('product-a', 'SKU-A', 'Product A'),
    ('product-b', 'SKU-B', 'Product B'),
  ]) {
    await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            id: product.$1,
            organizationId: 'organization',
            unitId: 'unit',
            sku: product.$2,
            normalizedSku: product.$2.toLowerCase().replaceAll('-', ''),
            name: product.$3,
            normalizedName: product.$3.toLowerCase().replaceAll(' ', ''),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
  await database
      .into(database.stockLocations)
      .insert(
        StockLocationsCompanion.insert(
          id: 'location',
          organizationId: 'organization',
          branchId: 'branch',
          code: 'WAREHOUSE',
          name: 'Warehouse',
          isDefault: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

class _SequenceIdGenerator implements IdGenerator {
  var _value = 0;

  @override
  String newId() => 'generated-${_value++}';
}
