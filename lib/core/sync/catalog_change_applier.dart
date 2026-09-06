import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'remote_change_envelope.dart';

class CatalogChangeApplier {
  const CatalogChangeApplier(this.database);

  final AppDatabase database;

  Future<bool> apply(RemoteChangeEnvelope envelope) async {
    switch (envelope.change.aggregateType) {
      case 'category':
        await _category(envelope);
      case 'unit':
        await _unit(envelope);
      case 'tax_category':
        await _taxCategory(envelope);
      case 'product':
        await _product(envelope);
      case 'product_price':
        await _price(envelope);
      case 'product_image':
        await _image(envelope);
      default:
        return false;
    }
    return true;
  }

  Future<void> _category(RemoteChangeEnvelope envelope) async {
    final payload = envelope.commandPayload;
    final result = _map(envelope.result['category']);
    final id = envelope.change.aggregateId;
    final existing = await (database.select(
      database.categories,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    final archived =
        envelope.change.changeType == 'tombstone' ||
        envelope.commandType.endsWith('.archive');
    final name = _string(payload['name']) ?? existing?.name;
    if (name == null) return;
    final now = envelope.change.occurredAt;
    await database
        .into(database.categories)
        .insertOnConflictUpdate(
          CategoriesCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            name: name,
            normalizedName: _normalize(name),
            isActive: Value(!archived),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            deletedAt: Value(archived ? now : null),
          ),
        );
    _checkResultVersion(result, envelope);
  }

  Future<void> _taxCategory(RemoteChangeEnvelope envelope) async {
    final row = _requiredMap(envelope.result['taxCategory'], 'taxCategory');
    final id = envelope.change.aggregateId;
    final existing = await (database.select(
      database.taxCategories,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    final now = envelope.change.occurredAt;
    final active = row['isActive'] == true;
    await database
        .into(database.taxCategories)
        .insertOnConflictUpdate(
          TaxCategoriesCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            code: _requiredString(row, 'code'),
            name: _requiredString(row, 'name'),
            rateBasisPoints: (row['rateBasisPoints'] as num).toInt(),
            isInclusive: Value(row['isInclusive'] == true),
            isActive: Value(active),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            deletedAt: Value(active ? null : now),
          ),
        );
  }

  Future<void> _unit(RemoteChangeEnvelope envelope) async {
    final payload = envelope.commandPayload;
    final result = _map(envelope.result['unit']);
    final id = envelope.change.aggregateId;
    final existing = await (database.select(
      database.units,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    final archived =
        envelope.change.changeType == 'tombstone' ||
        envelope.commandType.endsWith('.archive');
    final code = _string(payload['code']) ?? existing?.code;
    final name = _string(payload['name']) ?? existing?.name;
    final abbreviation =
        _string(payload['abbreviation']) ?? existing?.abbreviation;
    if (code == null || name == null || abbreviation == null) return;
    final now = envelope.change.occurredAt;
    await database
        .into(database.units)
        .insertOnConflictUpdate(
          UnitsCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            code: code,
            name: name,
            abbreviation: abbreviation,
            allowsFractional: Value(
              payload['allowsFractional'] as bool? ??
                  existing?.allowsFractional ??
                  false,
            ),
            isActive: Value(!archived),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            deletedAt: Value(archived ? now : null),
          ),
        );
    _checkResultVersion(result, envelope);
  }

  Future<void> _product(RemoteChangeEnvelope envelope) async {
    final product = _requiredMap(envelope.result['product'], 'product');
    final id = envelope.change.aggregateId;
    final existing = await (database.select(
      database.products,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    final now = _date(product['updated_at']) ?? envelope.change.occurredAt;
    final sku = _requiredString(product, 'sku');
    final name = _requiredString(product, 'name');
    final deletedAt = _date(product['deleted_at']);
    await database
        .into(database.products)
        .insertOnConflictUpdate(
          ProductsCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            categoryId: Value(_string(product['category_id'])),
            unitId: _requiredString(product, 'unit_id'),
            taxCategoryId: Value(_string(product['tax_category_id'])),
            sku: sku,
            normalizedSku: _normalize(sku),
            name: name,
            normalizedName: _normalize(name),
            description: Value(_string(product['description'])),
            isActive: Value(product['is_active'] == true && deletedAt == null),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            deletedAt: Value(deletedAt),
          ),
        );

    await (database.delete(
      database.productBarcodes,
    )..where((row) => row.productId.equals(id))).go();
    final barcodes = product['barcodes'];
    if (barcodes is List) {
      for (final value in barcodes) {
        final barcode = _requiredMap(value, 'barcode');
        final text = _requiredString(barcode, 'barcode');
        final timestamp = _date(barcode['updated_at']) ?? now;
        await database
            .into(database.productBarcodes)
            .insertOnConflictUpdate(
              ProductBarcodesCompanion.insert(
                id: _requiredString(barcode, 'id'),
                organizationId: envelope.change.organizationId,
                productId: id,
                barcode: text,
                normalizedBarcode: _normalize(text),
                isPrimary: Value(barcode['is_primary'] == true),
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            );
      }
    }
    final prices = product['prices'];
    if (prices is List) {
      for (final value in prices) {
        await _upsertPrice(envelope, _requiredMap(value, 'price'), id);
      }
    }
  }

  Future<void> _price(RemoteChangeEnvelope envelope) async {
    final price = _requiredMap(envelope.result['productPrice'], 'productPrice');
    await _upsertPrice(
      envelope,
      price,
      _requiredString(price, 'productId'),
      camelCase: true,
    );
  }

  Future<void> _upsertPrice(
    RemoteChangeEnvelope envelope,
    Map<String, Object?> price,
    String productId, {
    bool camelCase = false,
  }) async {
    final branchId = _string(price[camelCase ? 'branchId' : 'branch_id']);
    final effectiveAt =
        _date(price[camelCase ? 'effectiveFrom' : 'effective_from']) ??
        envelope.change.occurredAt;
    final id = _requiredString(price, 'id');
    final conflicting =
        await (database.select(database.productPrices)..where(
              (row) =>
                  row.productId.equals(productId) &
                  row.branchScope.equals(branchId ?? '*') &
                  row.effectiveFrom.equals(effectiveAt) &
                  row.id.equals(id).not(),
            ))
            .getSingleOrNull();
    if (conflicting != null) {
      await (database.delete(
        database.productPrices,
      )..where((row) => row.id.equals(conflicting.id))).go();
    }
    await database
        .into(database.productPrices)
        .insertOnConflictUpdate(
          ProductPricesCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            productId: productId,
            branchId: Value(branchId),
            branchScope: branchId ?? '*',
            unitPriceMinor: _integer(
              price[camelCase ? 'unitPriceMinor' : 'unit_price_minor'],
            ),
            effectiveFrom: effectiveAt,
            createdByUserId: envelope.actorUserId,
            createdAt: envelope.change.occurredAt,
          ),
        );
  }

  Future<void> _image(RemoteChangeEnvelope envelope) async {
    final image = _requiredMap(envelope.result['productImage'], 'productImage');
    final id = envelope.change.aggregateId;
    final existing = await (database.select(
      database.productImages,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    final now = _date(image['updated_at']) ?? envelope.change.occurredAt;
    await database
        .into(database.productImages)
        .insertOnConflictUpdate(
          ProductImagesCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            productId: _requiredString(image, 'product_id'),
            localPath: Value(existing?.localPath),
            remoteUrl: Value(_string(image['remote_url'])),
            uploadStatus: const Value('uploaded'),
            sortOrder: Value(existing?.sortOrder ?? 0),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
  }

  void _checkResultVersion(
    Map<String, Object?>? result,
    RemoteChangeEnvelope envelope,
  ) {
    final version = result?['version'];
    if (version != null && _integer(version) != envelope.change.version) {
      throw const FormatException(
        'Remote change version does not match its payload.',
      );
    }
  }
}

Map<String, Object?>? _map(Object? value) {
  if (value is! Map) return null;
  return value.map((key, item) => MapEntry(key.toString(), item));
}

Map<String, Object?> _requiredMap(Object? value, String field) {
  return _map(value) ?? (throw FormatException('$field must be an object.'));
}

String? _string(Object? value) => value?.toString();

String _requiredString(Map<String, Object?> value, String key) {
  return _string(value[key]) ?? (throw FormatException('$key is required.'));
}

int _integer(Object? value) => value is int
    ? value
    : int.parse(
        value?.toString() ?? (throw const FormatException('Integer required.')),
      );

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value.toString()).toUtc();

String _normalize(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
