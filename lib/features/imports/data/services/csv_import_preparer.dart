import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/models/business_context.dart';
import '../../../products/domain/entities/product_draft.dart';
import '../../../products/domain/entities/product_barcode_draft.dart';
import '../../../products/domain/use_cases/validate_product_use_case.dart';
import '../../../products/domain/value_objects/catalog_normalizer.dart';
import '../../../products/domain/value_objects/minor_unit_parser.dart';
import '../../domain/entities/csv_import.dart';
import '../../domain/services/csv_document_parser.dart';

class PreparedImportRow {
  const PreparedImportRow({
    required this.summary,
    this.productId,
    this.draft,
    this.locationId,
    this.quantityMilli,
  });
  final CsvImportRow summary;
  final String? productId;
  final ProductDraft? draft;
  final String? locationId;
  final int? quantityMilli;
}

class PreparedImport {
  const PreparedImport(this.preview, this.rows);
  final CsvImportPreview preview;
  final List<PreparedImportRow> rows;
}

class CsvImportPreparer {
  const CsvImportPreparer(this.database);
  final AppDatabase database;

  Future<PreparedImport> prepare(
    BusinessContext context,
    CsvImportKind kind,
    String source,
  ) async {
    if (utf8.encode(source).length > 5 * 1024 * 1024) {
      throw const FormatException('Use a CSV file smaller than 5 MB.');
    }
    final parsed = const CsvDocumentParser().parse(
      source,
      requiredHeaders: kind == CsvImportKind.catalog
          ? {'sku', 'name', 'unit_code', 'price'}
          : {'sku', 'location_code', 'quantity'},
      allowedHeaders: kind.headers.split(',').toSet(),
    );
    final products = await (database.select(
      database.products,
    )..where((row) => row.organizationId.equals(context.organizationId))).get();
    final units = await (database.select(
      database.units,
    )..where((row) => row.organizationId.equals(context.organizationId))).get();
    final categories = await (database.select(
      database.categories,
    )..where((row) => row.organizationId.equals(context.organizationId))).get();
    final taxes = await (database.select(
      database.taxCategories,
    )..where((row) => row.organizationId.equals(context.organizationId))).get();
    final barcodes =
        await (database.select(database.productBarcodes)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.deletedAt.isNull(),
            ))
            .get();
    final locations =
        await (database.select(database.stockLocations)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId),
            ))
            .get();
    final history = kind != CsvImportKind.openingStock
        ? <QueryRow>[]
        : await database
              .customSelect(
                'SELECT DISTINCT product_id, stock_location_id FROM inventory_ledger_entries WHERE organization_id = ? AND branch_id = ?',
                variables: [
                  Variable.withString(context.organizationId),
                  Variable.withString(context.branchId),
                ],
                readsFrom: {database.inventoryLedgerEntries},
              )
              .get();
    final historyKeys = {
      for (final row in history)
        '${row.read<String>('product_id')}:${row.read<String>('stock_location_id')}',
    };
    final bySku = {for (final row in products) row.normalizedSku: row};
    final byUnit = {for (final row in units) row.code.toUpperCase(): row};
    final byCategory = {for (final row in categories) row.normalizedName: row};
    final byTax = {for (final row in taxes) row.code.toUpperCase(): row};
    final byLocation = {
      for (final row in locations) row.code.toUpperCase(): row,
    };
    final barcodeOwners = {
      for (final row in barcodes) row.normalizedBarcode: row.productId,
    };
    final barcodesByProduct = <String, List<ProductBarcode>>{};
    for (final row in barcodes) {
      (barcodesByProduct[row.productId] ??= []).add(row);
    }
    for (final rows in barcodesByProduct.values) {
      rows.sort((a, b) {
        final primary = (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0);
        return primary != 0 ? primary : a.id.compareTo(b.id);
      });
    }
    final unitsById = {for (final row in units) row.id: row};
    final priceRevisions = <String, List<String>>{};
    if (kind == CsvImportKind.catalog) {
      final prices =
          await (database.select(database.productPrices)
                ..where(
                  (row) => row.organizationId.equals(context.organizationId),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.id)]))
              .get();
      for (final row in prices) {
        (priceRevisions[row.productId] ??= []).add(
          '${row.id}:${row.unitPriceMinor}:${row.effectiveFrom}:${row.effectiveTo}',
        );
      }
    }
    final seenRecords = <String>{};
    final seenBarcodes = <String>{};
    final result = <PreparedImportRow>[];
    final revisions = <String>[];
    for (var index = 0; index < parsed.length; index++) {
      final input = parsed[index];
      final sku = CatalogNormalizer.sku(input['sku']!);
      final existing = bySku[sku];
      final errors = <String>[];
      final duplicateKey = kind == CsvImportKind.catalog
          ? sku
          : '$sku:${input['location_code']!.toUpperCase()}';
      if (!seenRecords.add(duplicateKey)) {
        errors.add('This SKU/location occurs more than once in the file.');
      }
      if (existing != null &&
          (!existing.isActive || existing.deletedAt != null)) {
        errors.add('Restore the archived product first.');
      }
      ProductDraft? draft;
      String? locationId;
      int? quantity;
      if (kind == CsvImportKind.catalog) {
        final unit = byUnit[input['unit_code']!.toUpperCase()];
        final categoryName = input['category'];
        final category = categoryName == null || categoryName.isEmpty
            ? null
            : byCategory[CatalogNormalizer.search(categoryName)];
        final taxCode = input['tax_code'];
        final tax = taxCode == null || taxCode.isEmpty
            ? null
            : byTax[taxCode.toUpperCase()];
        if (unit == null || !unit.isActive || unit.deletedAt != null) {
          errors.add('Unit code is unknown or archived.');
        }
        if (categoryName != null &&
            categoryName.isNotEmpty &&
            (category == null ||
                !category.isActive ||
                category.deletedAt != null)) {
          errors.add('Category is unknown or archived.');
        }
        if (taxCode != null &&
            taxCode.isNotEmpty &&
            (tax == null || !tax.isActive || tax.deletedAt != null)) {
          errors.add('Tax code is unknown or archived.');
        }
        final price = MinorUnitParser.tryParse(input['price']!);
        if (price == null) {
          errors.add('Price must be non-negative with at most two decimals.');
        }
        final oldBarcodes = barcodesByProduct[existing?.id] ?? [];
        final barcodeValues = input.containsKey('barcodes')
            ? input['barcodes']!
                  .split('|')
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList()
            : oldBarcodes.map((row) => row.barcode).toList();
        final primary = input['primary_barcode']?.trim();
        final primaryValue = primary == null || primary.isEmpty
            ? (barcodeValues.isEmpty ? null : barcodeValues.first)
            : primary;
        final barcodeDrafts = [
          for (final value in barcodeValues)
            ProductBarcodeDraft(
              value: value,
              isPrimary:
                  CatalogNormalizer.barcode(value) ==
                  CatalogNormalizer.barcode(primaryValue ?? ''),
            ),
        ];
        for (final value in barcodeValues) {
          final normalized = CatalogNormalizer.barcode(value);
          if (!seenBarcodes.add(normalized)) {
            errors.add('Barcode $value is repeated in the file.');
          }
          final owner = barcodeOwners[normalized];
          if (owner != null && owner != existing?.id) {
            errors.add('Barcode $value belongs to another product.');
          }
        }
        draft = ProductDraft(
          sku: sku,
          name: input['name']!,
          unitId: unit?.id ?? '',
          unitPriceMinor: price ?? 0,
          categoryId: input.containsKey('category')
              ? category?.id
              : existing?.categoryId,
          taxCategoryId: input.containsKey('tax_code')
              ? tax?.id
              : existing?.taxCategoryId,
          description: input['description'] ?? existing?.description,
          barcodeDrafts: barcodeDrafts,
          preserveBranchPrices: true,
        ).normalized();
        final validation = const ValidateProductUseCase()(draft);
        if (validation.failureOrNull case final failure?) {
          errors.add(failure.message);
        }
        revisions.add(
          '${existing?.updatedAt}:${unit?.updatedAt}:${category?.updatedAt}:${tax?.updatedAt}:${barcodeValues.join('|')}:${priceRevisions[existing?.id]}',
        );
      } else {
        final location = byLocation[input['location_code']!.toUpperCase()];
        locationId = location?.id;
        if (existing == null) {
          errors.add('SKU does not exist. Import the catalog first.');
        }
        if (location == null ||
            !location.isActive ||
            location.deletedAt != null) {
          errors.add('Stock location is unknown or archived.');
        }
        quantity = _quantity(input['quantity']!);
        if (quantity == null || quantity <= 0) {
          errors.add('Quantity must be positive with at most three decimals.');
        }
        if (existing != null && quantity != null) {
          final unit = unitsById[existing.unitId];
          if (unit != null && !unit.allowsFractional && quantity % 1000 != 0) {
            errors.add('This product uses whole-unit quantities.');
          }
        }
        if (historyKeys.contains('${existing?.id}:$locationId')) {
          errors.add('This product/location already has ledger history.');
        }
        revisions.add(
          '${existing?.updatedAt}:${location?.updatedAt}:${existing?.id}:$locationId',
        );
      }
      result.add(
        PreparedImportRow(
          productId: existing?.id,
          draft: draft,
          locationId: locationId,
          quantityMilli: quantity,
          summary: CsvImportRow(
            number: index + 2,
            sku: sku,
            action: kind == CsvImportKind.openingStock
                ? 'Opening balance'
                : existing == null
                ? 'Create product'
                : 'Update product',
            errors: List.unmodifiable(errors),
          ),
        ),
      );
    }
    return PreparedImport(
      CsvImportPreview(
        kind: kind,
        source: source,
        revision: const Uuid().v5(Namespace.url.value, jsonEncode(revisions)),
        rows: List.unmodifiable(result.map((row) => row.summary)),
      ),
      List.unmodifiable(result),
    );
  }

  int? _quantity(String value) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,3}))?$').firstMatch(value);
    if (match == null) return null;
    final whole = int.tryParse(match.group(1)!);
    if (whole == null || whole > 9007199254739) return null;
    return whole * 1000 + int.parse((match.group(2) ?? '').padRight(3, '0'));
  }
}
