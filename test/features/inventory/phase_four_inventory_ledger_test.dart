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
import 'package:jce_pos/features/inventory/domain/entities/inventory_adjustment.dart';
import 'package:jce_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:jce_pos/features/inventory/domain/entities/inventory_transaction_type.dart';
import 'package:jce_pos/features/inventory/domain/entities/stock_count.dart';
import 'package:jce_pos/shared/models/business_context.dart';

void main() {
  late AppDatabase database;
  late DriftInventoryRepository repository;

  const context = BusinessContext(
    organizationId: 'organization',
    branchId: 'branch',
    actorUserId: 'app-user',
  );

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftInventoryRepository(
      database: database,
      localDataSource: InventoryLocalDataSource(database),
      localMutationTransaction: LocalMutationTransaction(database),
      idGenerator: _SequenceIdGenerator(),
      clock: FixedAppClock(DateTime.utc(2026, 8, 24, 8)),
    );
    await _seedInventoryContext(database);
  });

  tearDown(() => database.close());

  test('every movement updates its balance exactly once', () async {
    await repository.postMovement(
      context: context,
      draft: const InventoryMovementDraft(
        operationId: 'opening-operation',
        type: InventoryTransactionType.openingBalance,
        lines: [
          InventoryMovementLineDraft(
            stockLocationId: 'location',
            productId: 'product-a',
            quantityDeltaMilli: 2000,
          ),
        ],
      ),
    );
    final adjustment = await repository.createAdjustment(
      context: context,
      draft: const InventoryAdjustmentDraft(
        operationId: 'adjustment-operation',
        stockLocationId: 'location',
        productId: 'product-a',
        quantityDeltaMilli: -500,
        reasonCode: 'Damaged item',
        expectedBalanceVersion: 1,
      ),
    );

    final balance = await _balance(database, 'product-a');
    expect(adjustment.isSuccess, isTrue);
    expect(balance.onHandMilli, 1500);
    expect(balance.version, 2);
    expect(
      await database.select(database.inventoryLedgerEntries).get(),
      hasLength(2),
    );
    expect(
      await database.select(database.syncOutboxEntries).get(),
      hasLength(2),
    );
  });

  test('retrying the same operation does not duplicate stock', () async {
    const draft = InventoryMovementDraft(
      operationId: 'idempotent-opening',
      type: InventoryTransactionType.openingBalance,
      lines: [
        InventoryMovementLineDraft(
          stockLocationId: 'location',
          productId: 'product-a',
          quantityDeltaMilli: 1000,
        ),
      ],
    );

    final first = await repository.postMovement(context: context, draft: draft);
    final retry = await repository.postMovement(context: context, draft: draft);

    expect(first.valueOrNull, retry.valueOrNull);
    expect((await _balance(database, 'product-a')).onHandMilli, 1000);
    expect(
      await database.select(database.inventoryTransactions).get(),
      hasLength(1),
    );
    expect(
      await database.select(database.inventoryLedgerEntries).get(),
      hasLength(1),
    );
    expect(
      await database.select(database.syncOutboxEntries).get(),
      hasLength(1),
    );
  });

  test('a reversal restores stock without deleting ledger history', () async {
    final opening = await repository.postMovement(
      context: context,
      draft: const InventoryMovementDraft(
        operationId: 'opening-for-reversal',
        type: InventoryTransactionType.openingBalance,
        lines: [
          InventoryMovementLineDraft(
            stockLocationId: 'location',
            productId: 'product-a',
            quantityDeltaMilli: 2500,
          ),
        ],
      ),
    );
    final reversal = await repository.reverseMovement(
      context: context,
      transactionId: opening.valueOrNull!,
      reason: 'Opening balance entered twice',
      operationId: 'reversal-operation',
    );

    final transactions = await database
        .select(database.inventoryTransactions)
        .get();
    final ledger = await database.select(database.inventoryLedgerEntries).get();
    expect(reversal.isSuccess, isTrue);
    expect((await _balance(database, 'product-a')).onHandMilli, 0);
    expect(transactions, hasLength(2));
    expect(
      transactions.singleWhere((row) => row.id == opening.valueOrNull).status,
      'reversed',
    );
    expect(
      transactions
          .singleWhere((row) => row.id == reversal.valueOrNull)
          .reversesTransactionId,
      opening.valueOrNull,
    );
    expect(
      ledger.map((row) => row.quantityDeltaMilli),
      containsAll([2500, -2500]),
    );
  });

  test('negative stock follows the active branch policy', () async {
    final denied = await repository.postMovement(
      context: context,
      draft: const InventoryMovementDraft(
        operationId: 'negative-denied',
        type: InventoryTransactionType.sale,
        lines: [
          InventoryMovementLineDraft(
            stockLocationId: 'location',
            productId: 'product-a',
            quantityDeltaMilli: -1000,
          ),
        ],
      ),
    );
    expect(denied.failureOrNull, isA<ValidationFailure>());

    await repository.configurePolicy(
      context: context,
      policy: const InventoryPolicy(allowNegativeStock: true),
    );
    final allowed = await repository.postMovement(
      context: context,
      draft: const InventoryMovementDraft(
        operationId: 'negative-allowed',
        type: InventoryTransactionType.sale,
        lines: [
          InventoryMovementLineDraft(
            stockLocationId: 'location',
            productId: 'product-a',
            quantityDeltaMilli: -1000,
          ),
        ],
      ),
    );

    expect(allowed.isSuccess, isTrue);
    expect((await _balance(database, 'product-a')).onHandMilli, -1000);
  });

  test('stale balance versions detect concurrent adjustments', () async {
    await _openingBalance(
      repository,
      context,
      productId: 'product-a',
      quantity: 3000,
    );
    final first = await repository.createAdjustment(
      context: context,
      draft: const InventoryAdjustmentDraft(
        operationId: 'first-concurrent-adjustment',
        stockLocationId: 'location',
        productId: 'product-a',
        quantityDeltaMilli: 500,
        reasonCode: 'Recount',
        expectedBalanceVersion: 1,
      ),
    );
    final stale = await repository.createAdjustment(
      context: context,
      draft: const InventoryAdjustmentDraft(
        operationId: 'stale-concurrent-adjustment',
        stockLocationId: 'location',
        productId: 'product-a',
        quantityDeltaMilli: 500,
        reasonCode: 'Recount',
        expectedBalanceVersion: 1,
      ),
    );

    expect(first.isSuccess, isTrue);
    expect(stale.failureOrNull, isA<ConflictFailure>());
    expect((await _balance(database, 'product-a')).onHandMilli, 3500);
    expect(
      await database.select(database.inventoryLedgerEntries).get(),
      hasLength(2),
    );
  });

  test('count completion creates only required variance entries', () async {
    await repository.postMovement(
      context: context,
      draft: const InventoryMovementDraft(
        operationId: 'count-opening',
        type: InventoryTransactionType.openingBalance,
        lines: [
          InventoryMovementLineDraft(
            stockLocationId: 'location',
            productId: 'product-a',
            quantityDeltaMilli: 5000,
          ),
          InventoryMovementLineDraft(
            stockLocationId: 'location',
            productId: 'product-b',
            quantityDeltaMilli: 2000,
          ),
        ],
      ),
    );
    final started = await repository.startStockCount(
      context: context,
      draft: const StartStockCountDraft(
        operationId: 'full-count-start',
        stockLocationId: 'location',
        type: StockCountType.full,
      ),
    );
    final count =
        (await repository.watchStockCounts(context: context).first).single;
    final productA = count.items.singleWhere(
      (item) => item.productId == 'product-a',
    );
    final productB = count.items.singleWhere(
      (item) => item.productId == 'product-b',
    );
    await repository.recordCountedQuantity(
      context: context,
      stockCountId: started.valueOrNull!,
      itemId: productA.id,
      countedQuantityMilli: 4000,
      expectedVersion: productA.version,
    );
    await repository.recordCountedQuantity(
      context: context,
      stockCountId: started.valueOrNull!,
      itemId: productB.id,
      countedQuantityMilli: 2000,
      expectedVersion: productB.version,
    );

    final completed = await repository.completeStockCount(
      context: context,
      stockCountId: started.valueOrNull!,
      expectedVersion: count.version,
      operationId: 'full-count-complete',
    );
    final retry = await repository.completeStockCount(
      context: context,
      stockCountId: started.valueOrNull!,
      expectedVersion: count.version,
      operationId: 'full-count-complete',
    );

    final correctionEntries = await (database.select(
      database.inventoryLedgerEntries,
    )..where((row) => row.transactionId.equals(completed.valueOrNull!))).get();
    expect(completed.isSuccess, isTrue);
    expect(retry.valueOrNull, completed.valueOrNull);
    expect(correctionEntries, hasLength(1));
    expect(correctionEntries.single.productId, 'product-a');
    expect(correctionEntries.single.quantityDeltaMilli, -1000);
    expect((await _balance(database, 'product-a')).onHandMilli, 4000);
    expect((await _balance(database, 'product-b')).onHandMilli, 2000);
  });

  test('an active stock count freezes movements at its location', () async {
    await repository.startStockCount(
      context: context,
      draft: const StartStockCountDraft(
        operationId: 'freeze-count',
        stockLocationId: 'location',
        type: StockCountType.cycle,
        productIds: ['product-a'],
      ),
    );

    final adjustment = await repository.createAdjustment(
      context: context,
      draft: const InventoryAdjustmentDraft(
        operationId: 'blocked-during-count',
        stockLocationId: 'location',
        productId: 'product-a',
        quantityDeltaMilli: 1000,
        reasonCode: 'Recount',
        expectedBalanceVersion: 0,
      ),
    );

    expect(adjustment.failureOrNull, isA<ConflictFailure>());
    expect(await database.select(database.inventoryBalances).get(), isEmpty);
  });

  test('large adjustments require the configured manager approval', () async {
    await repository.configurePolicy(
      context: context,
      policy: const InventoryPolicy(
        allowNegativeStock: false,
        adjustmentApprovalThresholdMilli: 1000,
      ),
    );
    const draft = InventoryAdjustmentDraft(
      operationId: 'approval-required',
      stockLocationId: 'location',
      productId: 'product-a',
      quantityDeltaMilli: 1500,
      reasonCode: 'Large recount variance',
      expectedBalanceVersion: 0,
    );

    final denied = await repository.createAdjustment(
      context: context,
      draft: draft,
    );
    final approved = await repository.createAdjustment(
      context: context,
      draft: draft,
      approvedByUserId: 'manager-user',
    );

    expect(denied.failureOrNull, isA<AuthorizationFailure>());
    expect(approved.isSuccess, isTrue);
    expect((await _balance(database, 'product-a')).onHandMilli, 1500);
  });
}

Future<void> _openingBalance(
  DriftInventoryRepository repository,
  BusinessContext context, {
  required String productId,
  required int quantity,
}) async {
  await repository.postMovement(
    context: context,
    draft: InventoryMovementDraft(
      operationId: 'opening-$productId',
      type: InventoryTransactionType.openingBalance,
      lines: [
        InventoryMovementLineDraft(
          stockLocationId: 'location',
          productId: productId,
          quantityDeltaMilli: quantity,
        ),
      ],
    ),
  );
}

Future<InventoryBalance> _balance(AppDatabase database, String productId) {
  return (database.select(
    database.inventoryBalances,
  )..where((row) => row.productId.equals(productId))).getSingle();
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
