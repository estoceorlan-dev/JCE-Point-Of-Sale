import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../domain/entities/stock_transfer.dart';

class TransfersLocalDataSource {
  const TransfersLocalDataSource(this.database);

  final db.AppDatabase database;

  Stream<List<StockTransfer>> watchTransfers({
    required String organizationId,
    required String branchId,
  }) {
    final query = database.select(database.stockTransfers)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            (row.sourceBranchId.equals(branchId) |
                row.destinationBranchId.equals(branchId)),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch().asyncMap(
      (_) => _loadTransfers(organizationId, branchId),
    );
  }

  Future<StockTransfer?> getTransfer({
    required String organizationId,
    required String branchId,
    required String transferId,
  }) async {
    final row =
        await (database.select(database.stockTransfers)..where(
              (row) =>
                  row.id.equals(transferId) &
                  row.organizationId.equals(organizationId) &
                  (row.sourceBranchId.equals(branchId) |
                      row.destinationBranchId.equals(branchId)),
            ))
            .getSingleOrNull();
    return row == null ? null : _mapTransfer(row);
  }

  Future<List<StockTransfer>> _loadTransfers(
    String organizationId,
    String branchId,
  ) async {
    final rows =
        await (database.select(database.stockTransfers)
              ..where(
                (row) =>
                    row.organizationId.equals(organizationId) &
                    (row.sourceBranchId.equals(branchId) |
                        row.destinationBranchId.equals(branchId)),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
            .get();
    return Future.wait(rows.map(_mapTransfer));
  }

  Future<StockTransfer> _mapTransfer(db.StockTransfer row) async {
    final branches =
        await (database.select(database.branches)..where(
              (branch) =>
                  branch.id.equals(row.sourceBranchId) |
                  branch.id.equals(row.destinationBranchId),
            ))
            .get();
    final branchNames = {for (final branch in branches) branch.id: branch.name};
    final itemRows =
        await (database.select(database.stockTransferItems)
              ..where((item) => item.transferId.equals(row.id))
              ..orderBy([(item) => OrderingTerm.asc(item.createdAt)]))
            .get();
    final lines = <StockTransferLine>[];
    for (final item in itemRows) {
      final product = await (database.select(
        database.products,
      )..where((product) => product.id.equals(item.productId))).getSingle();
      final locations =
          await (database.select(database.stockLocations)..where(
                (location) =>
                    location.id.equals(item.sourceStockLocationId) |
                    location.id.equals(item.destinationStockLocationId) |
                    location.id.equals(item.damagedStockLocationId ?? ''),
              ))
              .get();
      final locationNames = {
        for (final location in locations) location.id: location.name,
      };
      lines.add(
        StockTransferLine(
          id: item.id,
          productId: item.productId,
          sku: product.sku,
          productName: product.name,
          sourceStockLocationId: item.sourceStockLocationId,
          sourceLocationName: locationNames[item.sourceStockLocationId] ?? '',
          destinationStockLocationId: item.destinationStockLocationId,
          destinationLocationName:
              locationNames[item.destinationStockLocationId] ?? '',
          damagedStockLocationId: item.damagedStockLocationId,
          damagedLocationName: item.damagedStockLocationId == null
              ? null
              : locationNames[item.damagedStockLocationId!],
          requestedQuantityMilli: item.requestedQuantityMilli,
          shippedQuantityMilli: item.shippedQuantityMilli,
          receivedQuantityMilli: item.receivedQuantityMilli,
          damagedQuantityMilli: item.damagedQuantityMilli,
          discrepancyQuantityMilli: item.discrepancyQuantityMilli,
          version: item.version,
        ),
      );
    }
    final eventRows =
        await (database.select(database.transferEvents)
              ..where((event) => event.transferId.equals(row.id))
              ..orderBy([(event) => OrderingTerm.desc(event.occurredAt)]))
            .get();
    return StockTransfer(
      id: row.id,
      transferNumber: row.transferNumber,
      sourceBranchId: row.sourceBranchId,
      sourceBranchName: branchNames[row.sourceBranchId] ?? row.sourceBranchId,
      destinationBranchId: row.destinationBranchId,
      destinationBranchName:
          branchNames[row.destinationBranchId] ?? row.destinationBranchId,
      status: StockTransferStatus.fromDatabase(row.status),
      approvalRequired: row.approvalRequired,
      createdByUserId: row.createdByUserId,
      approvedByUserId: row.approvedByUserId,
      notes: row.notes,
      rejectionReason: row.rejectionReason,
      cancellationReason: row.cancellationReason,
      version: row.version,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lines: lines,
      events: eventRows
          .map(
            (event) => TransferEvent(
              id: event.id,
              eventType: event.eventType,
              fromStatus: event.fromStatus == null
                  ? null
                  : StockTransferStatus.fromDatabase(event.fromStatus!),
              toStatus: StockTransferStatus.fromDatabase(event.toStatus),
              actorUserId: event.actorUserId,
              reason: event.reason,
              occurredAt: event.occurredAt,
            ),
          )
          .toList(growable: false),
    );
  }
}
