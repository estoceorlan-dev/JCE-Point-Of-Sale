import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/payment.dart' as domain;
import '../../domain/entities/sale.dart' as domain;
import '../../domain/entities/sale_correction.dart' as domain;
import '../../domain/entities/sale_product.dart';
import '../../domain/entities/sale_status.dart';

class SalesLocalDataSource {
  const SalesLocalDataSource(this._database);

  final AppDatabase _database;

  Future<SaleProduct?> getSaleProduct({
    required String organizationId,
    required String branchId,
    required String productId,
    required DateTime now,
  }) async {
    final products = _database.products;
    final units = _database.units;
    final taxCategories = _database.taxCategories;
    final productQuery =
        _database.select(products).join([
          innerJoin(
            units,
            units.id.equalsExp(products.unitId) &
                units.organizationId.equalsExp(products.organizationId),
          ),
          leftOuterJoin(
            taxCategories,
            taxCategories.id.equalsExp(products.taxCategoryId) &
                taxCategories.organizationId.equalsExp(products.organizationId),
          ),
        ])..where(
          products.id.equals(productId) &
              products.organizationId.equals(organizationId) &
              products.isActive.equals(true) &
              products.deletedAt.isNull(),
        );
    final productRow = await productQuery.getSingleOrNull();
    if (productRow == null) return null;

    final location =
        await (_database.select(_database.stockLocations)
              ..where(
                (row) =>
                    row.organizationId.equals(organizationId) &
                    row.branchId.equals(branchId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([
                (row) => OrderingTerm.desc(row.isDefault),
                (row) => OrderingTerm.asc(row.name),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (location == null) return null;

    final prices =
        await (_database.select(_database.productPrices)..where(
              (row) =>
                  row.organizationId.equals(organizationId) &
                  row.productId.equals(productId),
            ))
            .get();
    final effectivePrices =
        prices
            .where(
              (price) =>
                  (price.branchId == branchId || price.branchId == null) &&
                  !price.effectiveFrom.isAfter(now) &&
                  (price.effectiveTo == null ||
                      now.isBefore(price.effectiveTo!)),
            )
            .toList()
          ..sort((left, right) {
            final leftBranch = left.branchId == branchId ? 1 : 0;
            final rightBranch = right.branchId == branchId ? 1 : 0;
            final scope = rightBranch.compareTo(leftBranch);
            return scope != 0
                ? scope
                : right.effectiveFrom.compareTo(left.effectiveFrom);
          });
    if (effectivePrices.isEmpty) return null;

    final barcode =
        await (_database.select(_database.productBarcodes)
              ..where(
                (row) =>
                    row.organizationId.equals(organizationId) &
                    row.productId.equals(productId) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([
                (row) => OrderingTerm.desc(row.isPrimary),
                (row) => OrderingTerm.asc(row.createdAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    final balance =
        await (_database.select(_database.inventoryBalances)..where(
              (row) =>
                  row.organizationId.equals(organizationId) &
                  row.branchId.equals(branchId) &
                  row.stockLocationId.equals(location.id) &
                  row.productId.equals(productId),
            ))
            .getSingleOrNull();
    final product = productRow.readTable(products);
    final unit = productRow.readTable(units);
    final tax = productRow.readTableOrNull(taxCategories);
    return SaleProduct(
      id: product.id,
      sku: product.sku,
      name: product.name,
      unitName: unit.name,
      primaryBarcode: barcode?.barcode,
      stockLocationId: location.id,
      stockLocationName: location.name,
      unitPriceMinor: effectivePrices.first.unitPriceMinor,
      unitCostMinor: 0,
      taxRateBasisPoints: tax?.rateBasisPoints ?? 0,
      taxInclusive: tax?.isInclusive ?? true,
      availableQuantityMilli: balance?.onHandMilli ?? 0,
      inventoryVersion: balance?.version ?? 0,
    );
  }

  Stream<List<SaleProduct>> watchSaleProducts({
    required String organizationId,
    required String branchId,
    required String search,
    required DateTime now,
  }) {
    final nameSearch = _normalizeName(search);
    final skuSearch = search.trim().toUpperCase();
    final barcodeSearch = _normalizeBarcode(search);
    final hasSearch = nameSearch.isNotEmpty;
    final statement =
        '''
SELECT
  p.id,
  p.sku,
  p.name,
  u.name AS unit_name,
  sl.id AS stock_location_id,
  sl.name AS stock_location_name,
  COALESCE(ib.on_hand_milli, 0) AS available_quantity_milli,
  COALESCE(ib.version, 0) AS inventory_version,
  (
    SELECT pb.barcode FROM product_barcodes pb
    WHERE pb.product_id = p.id AND pb.deleted_at IS NULL
    ORDER BY pb.is_primary DESC, pb.created_at ASC LIMIT 1
  ) AS primary_barcode,
  COALESCE(
    (
      SELECT bp.unit_price_minor FROM product_prices bp
      WHERE bp.product_id = p.id AND bp.branch_id = ?
        AND bp.effective_from <= ?
        AND (bp.effective_to IS NULL OR bp.effective_to > ?)
      ORDER BY bp.effective_from DESC LIMIT 1
    ),
    (
      SELECT gp.unit_price_minor FROM product_prices gp
      WHERE gp.product_id = p.id AND gp.branch_id IS NULL
        AND gp.effective_from <= ?
        AND (gp.effective_to IS NULL OR gp.effective_to > ?)
      ORDER BY gp.effective_from DESC LIMIT 1
    ),
    0
  ) AS unit_price_minor,
  COALESCE(tc.rate_basis_points, 0) AS tax_rate_basis_points,
  COALESCE(tc.is_inclusive, 1) AS tax_inclusive
FROM products p
JOIN units u ON u.id = p.unit_id AND u.organization_id = p.organization_id
LEFT JOIN tax_categories tc
  ON tc.id = p.tax_category_id AND tc.organization_id = p.organization_id
JOIN stock_locations sl ON sl.id = (
  SELECT location.id FROM stock_locations location
  WHERE location.organization_id = p.organization_id
    AND location.branch_id = ?
    AND location.is_active = 1
    AND location.deleted_at IS NULL
  ORDER BY location.is_default DESC, location.name ASC LIMIT 1
)
LEFT JOIN inventory_balances ib
  ON ib.organization_id = p.organization_id
  AND ib.branch_id = ?
  AND ib.stock_location_id = sl.id
  AND ib.product_id = p.id
WHERE p.organization_id = ?
  AND p.is_active = 1
  AND p.deleted_at IS NULL
  ${hasSearch ? '''AND (
    p.normalized_name LIKE ? OR p.normalized_sku LIKE ? OR EXISTS (
      SELECT 1 FROM product_barcodes search_barcode
      WHERE search_barcode.product_id = p.id
        AND search_barcode.deleted_at IS NULL
        AND search_barcode.normalized_barcode LIKE ?
    )
  )''' : ''}
ORDER BY
  ${hasSearch ? '''CASE WHEN EXISTS (
    SELECT 1 FROM product_barcodes exact_barcode
    WHERE exact_barcode.product_id = p.id
      AND exact_barcode.deleted_at IS NULL
      AND exact_barcode.normalized_barcode = ?
  ) THEN 0 ELSE 1 END,''' : ''}
  p.normalized_name ASC, p.normalized_sku ASC
LIMIT 100
''';
    final variables = <Variable<Object>>[
      Variable<String>(branchId),
      Variable<DateTime>(now.toUtc()),
      Variable<DateTime>(now.toUtc()),
      Variable<DateTime>(now.toUtc()),
      Variable<DateTime>(now.toUtc()),
      Variable<String>(branchId),
      Variable<String>(branchId),
      Variable<String>(organizationId),
      if (hasSearch) ...[
        Variable<String>('%$nameSearch%'),
        Variable<String>('%$skuSearch%'),
        Variable<String>('%$barcodeSearch%'),
        Variable<String>(barcodeSearch),
      ],
    ];
    return _database
        .customSelect(
          statement,
          variables: variables,
          readsFrom: {
            _database.products,
            _database.units,
            _database.taxCategories,
            _database.productBarcodes,
            _database.productPrices,
            _database.stockLocations,
            _database.inventoryBalances,
          },
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => SaleProduct(
                  id: row.read<String>('id'),
                  sku: row.read<String>('sku'),
                  name: row.read<String>('name'),
                  unitName: row.read<String>('unit_name'),
                  primaryBarcode: row.readNullable<String>('primary_barcode'),
                  stockLocationId: row.read<String>('stock_location_id'),
                  stockLocationName: row.read<String>('stock_location_name'),
                  unitPriceMinor: row.read<int>('unit_price_minor'),
                  unitCostMinor: 0,
                  taxRateBasisPoints: row.read<int>('tax_rate_basis_points'),
                  taxInclusive: row.read<bool>('tax_inclusive'),
                  availableQuantityMilli: row.read<int>(
                    'available_quantity_milli',
                  ),
                  inventoryVersion: row.read<int>('inventory_version'),
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<List<domain.SaleRecord>> watchRecentSales({
    required String organizationId,
    required String branchId,
  }) {
    final sales = _database.sales;
    final registers = _database.registers;
    final returns = _database.saleReturns;
    final query =
        _database.select(sales).join([
            innerJoin(
              registers,
              registers.id.equalsExp(sales.registerId) &
                  registers.organizationId.equalsExp(sales.organizationId) &
                  registers.branchId.equalsExp(sales.branchId),
            ),
            leftOuterJoin(returns, returns.saleId.equalsExp(sales.id)),
          ])
          ..where(
            sales.organizationId.equals(organizationId) &
                sales.branchId.equals(branchId) &
                sales.status.equals('draft').not(),
          )
          ..groupBy([sales.id])
          ..orderBy([OrderingTerm.desc(sales.completedAt)])
          ..limit(50);
    return query.watch().asyncMap((rows) async {
      final result = <domain.SaleRecord>[];
      final seen = <String>{};
      for (final row in rows) {
        final sale = row.readTable(sales);
        if (!seen.add(sale.id)) continue;
        result.add(await _hydrate(sale, row.readTable(registers).name));
      }
      return result;
    });
  }

  Future<domain.SaleRecord?> getSale({
    required String organizationId,
    required String branchId,
    required String saleId,
  }) async {
    final sales = _database.sales;
    final registers = _database.registers;
    final query =
        _database.select(sales).join([
          innerJoin(
            registers,
            registers.id.equalsExp(sales.registerId) &
                registers.organizationId.equalsExp(sales.organizationId) &
                registers.branchId.equalsExp(sales.branchId),
          ),
        ])..where(
          sales.id.equals(saleId) &
              sales.organizationId.equals(organizationId) &
              sales.branchId.equals(branchId),
        );
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _hydrate(row.readTable(sales), row.readTable(registers).name);
  }

  Future<domain.SaleRecord> _hydrate(Sale sale, String registerName) async {
    final itemRows =
        await (_database.select(_database.saleItems)
              ..where((row) => row.saleId.equals(sale.id))
              ..orderBy([(row) => OrderingTerm.asc(row.lineNumber)]))
            .get();
    final paymentRows =
        await (_database.select(_database.payments)
              ..where((row) => row.saleId.equals(sale.id))
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
            .get();
    final correctionRows =
        await (_database.select(_database.saleReturns)
              ..where((row) => row.saleId.equals(sale.id))
              ..orderBy([(row) => OrderingTerm.asc(row.completedAt)]))
            .get();
    final corrections = <domain.SaleCorrectionRecord>[];
    final returnedByItem = <String, int>{};
    for (final correction in correctionRows) {
      final items = await _correctionItems(correction.id, itemRows);
      if (correction.status == 'completed') {
        for (final item in items) {
          returnedByItem.update(
            item.saleItemId,
            (quantity) => quantity + item.quantityMilli,
            ifAbsent: () => item.quantityMilli,
          );
        }
      }
      final refunds =
          await (_database.select(_database.refundPayments)
                ..where((row) => row.saleReturnId.equals(correction.id))
                ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
              .get();
      corrections.add(
        domain.SaleCorrectionRecord(
          id: correction.id,
          returnNumber: correction.returnNumber,
          type: domain.SaleCorrectionType.fromDatabase(
            correction.correctionType,
          ),
          status: correction.status,
          reasonCode: correction.reasonCode,
          notes: correction.notes,
          subtotalMinor: correction.subtotalMinor,
          discountMinor: correction.discountMinor,
          taxMinor: correction.taxMinor,
          totalMinor: correction.totalMinor,
          createdByUserId: correction.createdByUserId,
          approvedByUserId: correction.approvedByUserId,
          completedAt: correction.completedAt,
          items: items,
          refunds: refunds
              .map(
                (refund) => domain.RefundRecord(
                  id: refund.id,
                  method: domain.RefundMethod.fromDatabase(refund.refundMethod),
                  amountMinor: refund.amountMinor,
                  reference: refund.reference,
                ),
              )
              .toList(growable: false),
        ),
      );
    }
    final originalStatus = SaleStatus.fromDatabase(sale.status);
    final effectiveStatus = _effectiveStatus(
      originalStatus,
      itemRows,
      returnedByItem,
      corrections,
    );
    return domain.SaleRecord(
      id: sale.id,
      branchId: sale.branchId,
      registerId: sale.registerId,
      registerName: registerName,
      shiftId: sale.shiftId,
      receiptNumber: sale.receiptNumber ?? 'Pending',
      status: effectiveStatus,
      cashierUserId: sale.cashierUserId,
      subtotalMinor: sale.subtotalMinor,
      discountMinor: sale.discountMinor,
      taxMinor: sale.taxMinor,
      totalMinor: sale.totalMinor,
      tenderedMinor: sale.tenderedMinor,
      changeMinor: sale.changeMinor,
      completedAt: sale.completedAt ?? sale.createdAt,
      discountApprovedByUserId: sale.discountApprovedByUserId,
      items: itemRows
          .map(
            (item) => domain.SaleItem(
              id: item.id,
              productId: item.productId,
              stockLocationId: item.stockLocationId,
              lineNumber: item.lineNumber,
              productName: item.productNameSnapshot,
              sku: item.skuSnapshot,
              barcode: item.barcodeSnapshot,
              unitName: item.unitNameSnapshot,
              quantityMilli: item.quantityMilli,
              unitPriceMinor: item.unitPriceMinorSnapshot,
              unitCostMinor: item.unitCostMinorSnapshot,
              taxRateBasisPoints: item.taxRateBasisPointsSnapshot,
              taxInclusive: item.taxInclusiveSnapshot,
              grossAmountMinor: item.grossAmountMinor,
              discountAmountMinor: item.discountAmountMinor,
              netAmountMinor: item.netAmountMinor,
              taxAmountMinor: item.taxAmountMinor,
              totalAmountMinor: item.totalAmountMinor,
              returnedQuantityMilli: returnedByItem[item.id] ?? 0,
            ),
          )
          .toList(growable: false),
      payments: paymentRows
          .map(
            (payment) => domain.SalePayment(
              id: payment.id,
              method: domain.SalePaymentMethod.fromDatabase(
                payment.paymentMethod,
              ),
              tenderedAmountMinor: payment.tenderedAmountMinor,
              appliedAmountMinor: payment.appliedAmountMinor,
              changeAmountMinor: payment.changeAmountMinor,
              reference: payment.reference,
            ),
          )
          .toList(growable: false),
      corrections: corrections,
    );
  }

  Future<List<domain.SaleCorrectionItem>> _correctionItems(
    String correctionId,
    List<SaleItem> saleItems,
  ) async {
    final rows =
        await (_database.select(_database.saleReturnItems).join([
              leftOuterJoin(
                _database.stockLocations,
                _database.stockLocations.id.equalsExp(
                  _database.saleReturnItems.destinationStockLocationId,
                ),
              ),
            ])..where(
              _database.saleReturnItems.saleReturnId.equals(correctionId),
            ))
            .get();
    final products = {for (final item in saleItems) item.id: item};
    return rows
        .map((row) {
          final item = row.readTable(_database.saleReturnItems);
          final saleItem = products[item.saleItemId];
          return domain.SaleCorrectionItem(
            id: item.id,
            saleItemId: item.saleItemId,
            productId: item.productId,
            productName: saleItem?.productNameSnapshot ?? 'Product',
            quantityMilli: item.quantityMilli,
            disposition: domain.ReturnDisposition.fromDatabase(
              item.disposition,
            ),
            destinationStockLocationId: item.destinationStockLocationId,
            destinationName: row
                .readTableOrNull(_database.stockLocations)
                ?.name,
            subtotalMinor: item.subtotalMinor,
            discountMinor: item.discountMinor,
            taxMinor: item.taxMinor,
            totalMinor: item.totalMinor,
          );
        })
        .toList(growable: false);
  }
}

SaleStatus _effectiveStatus(
  SaleStatus original,
  List<SaleItem> items,
  Map<String, int> returnedByItem,
  List<domain.SaleCorrectionRecord> corrections,
) {
  if (original == SaleStatus.syncRejected) return original;
  if (corrections.any(
    (correction) =>
        correction.status == 'completed' &&
        correction.type == domain.SaleCorrectionType.voidSale,
  )) {
    return SaleStatus.voided;
  }
  final returned = returnedByItem.values.fold<int>(
    0,
    (total, quantity) => total + quantity,
  );
  if (returned == 0) return original;
  final sold = items.fold<int>(0, (total, item) => total + item.quantityMilli);
  return returned >= sold ? SaleStatus.returned : SaleStatus.partiallyReturned;
}

String _normalizeName(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _normalizeBarcode(String value) =>
    value.trim().replaceAll(RegExp(r'[\s-]+'), '');
