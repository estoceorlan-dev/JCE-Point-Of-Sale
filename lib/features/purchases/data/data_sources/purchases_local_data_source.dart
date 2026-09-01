import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../domain/entities/goods_receipt.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/supplier.dart';

class PurchasesLocalDataSource {
  const PurchasesLocalDataSource(this.database);

  final db.AppDatabase database;

  Stream<List<Supplier>> watchSuppliers({required String organizationId}) {
    final query = database.select(database.suppliers)
      ..where((row) => row.organizationId.equals(organizationId))
      ..orderBy([(row) => OrderingTerm.asc(row.normalizedName)]);
    return query.watch().asyncMap(
      (rows) => Future.wait(rows.map(_mapSupplier)),
    );
  }

  Stream<List<PurchaseOrder>> watchPurchaseOrders({
    required String organizationId,
    required String branchId,
  }) {
    final query = database.select(database.purchaseOrders)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            row.branchId.equals(branchId),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch().asyncMap(
      (rows) => Future.wait(rows.map(_mapPurchaseOrder)),
    );
  }

  Future<PurchaseOrder?> getPurchaseOrder({
    required String organizationId,
    required String branchId,
    required String purchaseOrderId,
  }) async {
    final row =
        await (database.select(database.purchaseOrders)..where(
              (row) =>
                  row.id.equals(purchaseOrderId) &
                  row.organizationId.equals(organizationId) &
                  row.branchId.equals(branchId),
            ))
            .getSingleOrNull();
    return row == null ? null : _mapPurchaseOrder(row);
  }

  Future<Supplier> _mapSupplier(db.Supplier row) async {
    final contacts =
        await (database.select(database.supplierContacts)
              ..where((contact) => contact.supplierId.equals(row.id))
              ..orderBy([
                (contact) => OrderingTerm.desc(contact.isPrimary),
                (contact) => OrderingTerm.asc(contact.name),
              ]))
            .get();
    return Supplier(
      id: row.id,
      code: row.code,
      name: row.name,
      taxIdentifier: row.taxIdentifier,
      paymentTermsDays: row.paymentTermsDays,
      isActive: row.isActive,
      version: row.version,
      contacts: contacts
          .map(
            (contact) => SupplierContact(
              id: contact.id,
              name: contact.name,
              role: contact.role,
              email: contact.email,
              phone: contact.phone,
              isPrimary: contact.isPrimary,
            ),
          )
          .toList(growable: false),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<PurchaseOrder> _mapPurchaseOrder(db.PurchaseOrder row) async {
    final supplier = await (database.select(
      database.suppliers,
    )..where((value) => value.id.equals(row.supplierId))).getSingle();
    final itemRows =
        await (database.select(database.purchaseOrderItems)
              ..where((item) => item.purchaseOrderId.equals(row.id))
              ..orderBy([(item) => OrderingTerm.asc(item.createdAt)]))
            .get();
    final lines = <PurchaseOrderLine>[];
    for (final item in itemRows) {
      final product = await (database.select(
        database.products,
      )..where((value) => value.id.equals(item.productId))).getSingle();
      lines.add(
        PurchaseOrderLine(
          id: item.id,
          productId: item.productId,
          sku: product.sku,
          productName: product.name,
          orderedQuantityMilli: item.orderedQuantityMilli,
          receivedQuantityMilli: item.receivedQuantityMilli,
          cancelledQuantityMilli: item.cancelledQuantityMilli,
          unitCostMinor: item.unitCostMinor,
          estimatedLandedCostMinor: item.estimatedLandedCostMinor,
          version: item.version,
        ),
      );
    }
    final receiptRows =
        await (database.select(database.goodsReceipts)
              ..where((receipt) => receipt.purchaseOrderId.equals(row.id))
              ..orderBy([(receipt) => OrderingTerm.desc(receipt.receivedAt)]))
            .get();
    final receipts = await Future.wait(receiptRows.map(_mapReceipt));
    return PurchaseOrder(
      id: row.id,
      orderNumber: row.orderNumber,
      supplierId: row.supplierId,
      supplierName: supplier.name,
      status: PurchaseOrderStatus.fromDatabase(row.status),
      createdByUserId: row.createdByUserId,
      approvedByUserId: row.approvedByUserId,
      notes: row.notes,
      expectedDeliveryAt: row.expectedDeliveryAt,
      cancellationReason: row.cancellationReason,
      version: row.version,
      lines: lines,
      receipts: receipts,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<GoodsReceipt> _mapReceipt(db.GoodsReceipt row) async {
    final location = await (database.select(
      database.stockLocations,
    )..where((value) => value.id.equals(row.stockLocationId))).getSingle();
    final itemRows = await (database.select(
      database.goodsReceiptItems,
    )..where((item) => item.goodsReceiptId.equals(row.id))).get();
    final lines = <GoodsReceiptLine>[];
    for (final item in itemRows) {
      final product = await (database.select(
        database.products,
      )..where((value) => value.id.equals(item.productId))).getSingle();
      lines.add(
        GoodsReceiptLine(
          id: item.id,
          purchaseOrderItemId: item.purchaseOrderItemId,
          productId: item.productId,
          productName: product.name,
          receivedQuantityMilli: item.receivedQuantityMilli,
          unitCostMinor: item.unitCostMinor,
          freightCostMinor: item.freightCostMinor,
          dutyCostMinor: item.dutyCostMinor,
          otherLandedCostMinor: item.otherLandedCostMinor,
          landedUnitCostMinor: item.landedUnitCostMinor,
          weightedAverageCostMinorAfter: item.weightedAverageCostMinorAfter,
        ),
      );
    }
    return GoodsReceipt(
      id: row.id,
      receiptNumber: row.receiptNumber,
      stockLocationId: row.stockLocationId,
      stockLocationName: location.name,
      receivedByUserId: row.receivedByUserId,
      receivedAt: row.receivedAt,
      supplierDocumentNumber: row.supplierDocumentNumber,
      notes: row.notes,
      lines: lines,
    );
  }
}
