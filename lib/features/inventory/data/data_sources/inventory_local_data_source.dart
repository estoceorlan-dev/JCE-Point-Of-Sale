import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/inventory_adjustment.dart';
import '../../domain/entities/inventory_balance.dart' as domain;
import '../../domain/entities/inventory_movement.dart' as domain;
import '../../domain/entities/inventory_transaction_type.dart';
import '../../domain/entities/stock_count.dart' as domain;
import '../../domain/entities/stock_location.dart' as domain;

class InventoryLocalDataSource {
  const InventoryLocalDataSource(this._database);

  final AppDatabase _database;

  Stream<List<domain.StockLocation>> watchStockLocations({
    required String organizationId,
    required String branchId,
  }) {
    final query = _database.select(_database.stockLocations)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            row.branchId.equals(branchId) &
            row.deletedAt.isNull(),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.isDefault),
        (row) => OrderingTerm.asc(row.name),
      ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => domain.StockLocation(
              id: row.id,
              organizationId: row.organizationId,
              branchId: row.branchId,
              code: row.code,
              name: row.name,
              type: domain.StockLocationType.fromDatabase(row.locationType),
              isDefault: row.isDefault,
              isActive: row.isActive,
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<List<domain.InventoryBalance>> watchBalances({
    required String organizationId,
    required String branchId,
    required domain.InventoryBalanceQuery filter,
  }) {
    final balances = _database.inventoryBalances;
    final products = _database.products;
    final locations = _database.stockLocations;
    final query =
        _database.select(balances).join([
          innerJoin(
            products,
            products.id.equalsExp(balances.productId) &
                products.organizationId.equalsExp(balances.organizationId),
          ),
          innerJoin(
            locations,
            locations.id.equalsExp(balances.stockLocationId) &
                locations.organizationId.equalsExp(balances.organizationId) &
                locations.branchId.equalsExp(balances.branchId),
          ),
        ])..where(
          balances.organizationId.equals(organizationId) &
              balances.branchId.equals(branchId),
        );
    final locationId = filter.stockLocationId?.trim();
    if (locationId != null && locationId.isNotEmpty) {
      query.where(balances.stockLocationId.equals(locationId));
    }
    if (filter.lowStockOnly) {
      query.where(
        balances.onHandMilli.isSmallerOrEqual(balances.reorderPointMilli),
      );
    }
    final search = _normalizeSearch(filter.search);
    if (search.isNotEmpty) {
      query.where(
        products.normalizedName.contains(search) |
            products.normalizedSku.contains(search),
      );
    }
    query.orderBy([
      OrderingTerm.asc(products.normalizedName),
      OrderingTerm.asc(locations.name),
    ]);
    return query.watch().map(
      (rows) => rows
          .map((row) {
            final balance = row.readTable(balances);
            final product = row.readTable(products);
            final location = row.readTable(locations);
            return domain.InventoryBalance(
              id: balance.id,
              productId: product.id,
              sku: product.sku,
              productName: product.name,
              stockLocationId: location.id,
              stockLocationName: location.name,
              onHandMilli: balance.onHandMilli,
              reservedMilli: balance.reservedMilli,
              reorderPointMilli: balance.reorderPointMilli,
              version: balance.version,
              updatedAt: balance.updatedAt,
            );
          })
          .toList(growable: false),
    );
  }

  Stream<List<domain.InventoryMovement>> watchMovements({
    required String organizationId,
    required String branchId,
    required domain.InventoryMovementFilter filter,
  }) {
    final transactions = _database.inventoryTransactions;
    final ledger = _database.inventoryLedgerEntries;
    final products = _database.products;
    final locations = _database.stockLocations;
    final query =
        _database.select(transactions).join([
          innerJoin(ledger, ledger.transactionId.equalsExp(transactions.id)),
          innerJoin(products, products.id.equalsExp(ledger.productId)),
          innerJoin(locations, locations.id.equalsExp(ledger.stockLocationId)),
        ])..where(
          transactions.organizationId.equals(organizationId) &
              transactions.branchId.equals(branchId),
        );
    if (filter.productId case final productId?) {
      query.where(ledger.productId.equals(productId));
    }
    if (filter.stockLocationId case final stockLocationId?) {
      query.where(ledger.stockLocationId.equals(stockLocationId));
    }
    if (filter.type case final type?) {
      query.where(transactions.transactionType.equals(type.databaseValue));
    }
    if (filter.from case final from?) {
      query.where(transactions.occurredAt.isBiggerOrEqualValue(from.toUtc()));
    }
    if (filter.to case final to?) {
      query.where(transactions.occurredAt.isSmallerOrEqualValue(to.toUtc()));
    }
    query.orderBy([OrderingTerm.desc(transactions.occurredAt)]);
    return query.watch().map((rows) {
      final grouped = <String, _MovementBuilder>{};
      for (final row in rows) {
        final transaction = row.readTable(transactions);
        final entry = row.readTable(ledger);
        final product = row.readTable(products);
        final location = row.readTable(locations);
        final builder = grouped.putIfAbsent(
          transaction.id,
          () => _MovementBuilder(
            id: transaction.id,
            operationId: transaction.operationId,
            type: InventoryTransactionType.fromDatabase(
              transaction.transactionType,
            ),
            status: transaction.status,
            createdByUserId: transaction.createdByUserId,
            occurredAt: transaction.occurredAt,
            reasonCode: transaction.reasonCode,
            notes: transaction.notes,
            referenceType: transaction.referenceType,
            referenceId: transaction.referenceId,
            reversesTransactionId: transaction.reversesTransactionId,
            approvedByUserId: transaction.approvedByUserId,
          ),
        );
        builder.lines.add(
          domain.InventoryMovementLine(
            id: entry.id,
            stockLocationId: location.id,
            stockLocationName: location.name,
            productId: product.id,
            sku: product.sku,
            productName: product.name,
            quantityDeltaMilli: entry.quantityDeltaMilli,
            balanceAfterMilli: entry.balanceAfterMilli,
          ),
        );
      }
      return grouped.values
          .take(filter.limit)
          .map((builder) => builder.build())
          .toList(growable: false);
    });
  }

  Stream<List<domain.StockCount>> watchStockCounts({
    required String organizationId,
    required String branchId,
  }) {
    final counts = _database.stockCounts;
    final items = _database.stockCountItems;
    final products = _database.products;
    final locations = _database.stockLocations;
    final query =
        _database.select(counts).join([
            innerJoin(
              locations,
              locations.id.equalsExp(counts.stockLocationId),
            ),
            leftOuterJoin(items, items.stockCountId.equalsExp(counts.id)),
            leftOuterJoin(products, products.id.equalsExp(items.productId)),
          ])
          ..where(
            counts.organizationId.equals(organizationId) &
                counts.branchId.equals(branchId),
          )
          ..orderBy([OrderingTerm.desc(counts.startedAt)]);
    return query.watch().map((rows) {
      final grouped = <String, _StockCountBuilder>{};
      for (final row in rows) {
        final count = row.readTable(counts);
        final location = row.readTable(locations);
        final builder = grouped.putIfAbsent(
          count.id,
          () => _StockCountBuilder(
            id: count.id,
            stockLocationId: location.id,
            stockLocationName: location.name,
            type: domain.StockCountType.fromDatabase(count.countType),
            status: domain.StockCountStatus.fromDatabase(count.status),
            startedAt: count.startedAt,
            version: count.version,
            notes: count.notes,
            completedAt: count.completedAt,
          ),
        );
        final item = row.readTableOrNull(items);
        final product = row.readTableOrNull(products);
        if (item != null && product != null) {
          builder.items.add(
            domain.StockCountItem(
              id: item.id,
              productId: product.id,
              sku: product.sku,
              productName: product.name,
              expectedQuantityMilli: item.expectedQuantityMilli,
              countedQuantityMilli: item.countedQuantityMilli,
              varianceQuantityMilli: item.varianceQuantityMilli,
              version: item.version,
            ),
          );
        }
      }
      return grouped.values.map((builder) => builder.build()).toList();
    });
  }

  Future<InventoryPolicy?> getPolicy({
    required String organizationId,
    required String branchId,
  }) async {
    final branch =
        await (_database.select(_database.branches)..where(
              (row) =>
                  row.id.equals(branchId) &
                  row.organizationId.equals(organizationId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (branch == null) return null;
    return InventoryPolicy(
      allowNegativeStock: branch.allowNegativeStock,
      adjustmentApprovalThresholdMilli: branch.adjustmentApprovalThresholdMilli,
    );
  }
}

class _MovementBuilder {
  _MovementBuilder({
    required this.id,
    required this.operationId,
    required this.type,
    required this.status,
    required this.createdByUserId,
    required this.occurredAt,
    required this.reasonCode,
    required this.notes,
    required this.referenceType,
    required this.referenceId,
    required this.reversesTransactionId,
    required this.approvedByUserId,
  });

  final String id;
  final String operationId;
  final InventoryTransactionType type;
  final String status;
  final String createdByUserId;
  final DateTime occurredAt;
  final String? reasonCode;
  final String? notes;
  final String? referenceType;
  final String? referenceId;
  final String? reversesTransactionId;
  final String? approvedByUserId;
  final List<domain.InventoryMovementLine> lines = [];

  domain.InventoryMovement build() => domain.InventoryMovement(
    id: id,
    operationId: operationId,
    type: type,
    status: status,
    lines: List.unmodifiable(lines),
    createdByUserId: createdByUserId,
    occurredAt: occurredAt,
    reasonCode: reasonCode,
    notes: notes,
    referenceType: referenceType,
    referenceId: referenceId,
    reversesTransactionId: reversesTransactionId,
    approvedByUserId: approvedByUserId,
  );
}

class _StockCountBuilder {
  _StockCountBuilder({
    required this.id,
    required this.stockLocationId,
    required this.stockLocationName,
    required this.type,
    required this.status,
    required this.startedAt,
    required this.version,
    required this.notes,
    required this.completedAt,
  });

  final String id;
  final String stockLocationId;
  final String stockLocationName;
  final domain.StockCountType type;
  final domain.StockCountStatus status;
  final DateTime startedAt;
  final int version;
  final String? notes;
  final DateTime? completedAt;
  final List<domain.StockCountItem> items = [];

  domain.StockCount build() => domain.StockCount(
    id: id,
    stockLocationId: stockLocationId,
    stockLocationName: stockLocationName,
    type: type,
    status: status,
    items: List.unmodifiable(items),
    startedAt: startedAt,
    version: version,
    notes: notes,
    completedAt: completedAt,
  );
}

String _normalizeSearch(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
