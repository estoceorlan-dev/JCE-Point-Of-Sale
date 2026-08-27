import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/catalog_category.dart';
import '../../domain/entities/catalog_drafts.dart';
import '../../domain/entities/catalog_tax_category.dart';
import '../../domain/entities/catalog_unit.dart';
import '../../domain/entities/product.dart' as domain;
import '../../domain/entities/product_draft.dart';
import '../../domain/entities/product_query.dart';
import '../../domain/entities/product_price.dart' as domain_price;
import '../../domain/entities/product_summary.dart';
import '../../domain/repositories/products_repository.dart';
import '../../domain/value_objects/catalog_normalizer.dart';
import '../data_sources/product_catalog_local_data_source.dart';

class DriftProductsRepository implements ProductsRepository {
  const DriftProductsRepository({
    required ProductCatalogLocalDataSource localDataSource,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _localDataSource = localDataSource,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock;

  final ProductCatalogLocalDataSource _localDataSource;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  @override
  Stream<ProductPage> watchProducts({
    required BusinessContext context,
    required ProductQuery query,
  }) {
    return _localDataSource.watchProducts(
      organizationId: context.organizationId,
      branchId: context.branchId,
      query: query,
      now: _clock.nowUtc(),
    );
  }

  @override
  Stream<List<CatalogCategory>> watchCategories({
    required BusinessContext context,
    bool includeArchived = false,
  }) {
    return _localDataSource.watchCategories(
      organizationId: context.organizationId,
      includeArchived: includeArchived,
    );
  }

  @override
  Stream<List<CatalogUnit>> watchUnits({
    required BusinessContext context,
    bool includeArchived = false,
  }) {
    return _localDataSource.watchUnits(
      organizationId: context.organizationId,
      includeArchived: includeArchived,
    );
  }

  @override
  Stream<List<CatalogTaxCategory>> watchTaxCategories({
    required BusinessContext context,
    bool includeArchived = false,
  }) {
    return _localDataSource.watchTaxCategories(
      organizationId: context.organizationId,
      includeArchived: includeArchived,
    );
  }

  @override
  Future<domain.Product?> getProduct({
    required BusinessContext context,
    required String productId,
  }) {
    return _localDataSource.getProduct(
      organizationId: context.organizationId,
      branchId: context.branchId,
      productId: productId,
      now: _clock.nowUtc(),
    );
  }

  @override
  Future<Result<String, Failure>> createProduct({
    required BusinessContext context,
    required ProductDraft draft,
  }) async {
    final priceFailure = _priceScopeFailure(
      context: context,
      draft: draft.price,
    );
    if (priceFailure != null) {
      return Result.failure(priceFailure);
    }
    final normalizedSku = CatalogNormalizer.sku(draft.sku);
    final normalizedBarcodes = draft.barcodes
        .map(CatalogNormalizer.barcode)
        .toList(growable: false);
    final duplicate = await _duplicateFailure(
      context: context,
      normalizedSku: normalizedSku,
      normalizedBarcodes: normalizedBarcodes,
    );
    if (duplicate != null) {
      return Result.failure(duplicate);
    }

    final productId = _idGenerator.newId();
    final priceId = _idGenerator.newId();
    final now = _clock.nowUtc();
    final operationId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _requireProductReferences(
          database: database,
          context: context,
          draft: draft,
        );
        await database
            .into(database.products)
            .insert(
              ProductsCompanion.insert(
                id: productId,
                organizationId: context.organizationId,
                categoryId: Value(draft.categoryId),
                unitId: draft.unitId,
                taxCategoryId: Value(draft.taxCategoryId),
                sku: draft.sku,
                normalizedSku: normalizedSku,
                name: draft.name,
                normalizedName: CatalogNormalizer.search(draft.name),
                description: Value(draft.description),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _replaceBarcodes(
          database: database,
          context: context,
          productId: productId,
          barcodes: draft.barcodes,
          now: now,
        );
        await _appendPrice(
          database: database,
          context: context,
          productId: productId,
          priceId: priceId,
          draft: draft.price,
          currentPrice: null,
          now: now,
        );
        await _appendImages(
          database: database,
          context: context,
          productId: productId,
          paths: draft.imagePaths,
          now: now,
        );
        return productId;
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.create,
        entityName: 'product',
        entityId: productId,
        metadata: {'sku': draft.sku, 'name': draft.name},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'product.create',
        aggregateType: 'product',
        aggregateId: productId,
        payload: _productPayload(productId, draft, priceId: priceId),
        now: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> updateProduct({
    required BusinessContext context,
    required String productId,
    required ProductDraft draft,
  }) async {
    final priceFailure = _priceScopeFailure(
      context: context,
      draft: draft.price,
    );
    if (priceFailure != null) {
      return Result.failure(priceFailure);
    }
    final existing = await getProduct(context: context, productId: productId);
    if (existing == null) {
      return const Result.failure(
        AuthorizationFailure(
          'The product is not available in this organization.',
          code: 'cross-organization-reference',
        ),
      );
    }
    final normalizedSku = CatalogNormalizer.sku(draft.sku);
    final duplicate = await _duplicateFailure(
      context: context,
      normalizedSku: normalizedSku,
      normalizedBarcodes: draft.barcodes
          .map(CatalogNormalizer.barcode)
          .toList(growable: false),
      excludingProductId: productId,
    );
    if (duplicate != null) {
      return Result.failure(duplicate);
    }

    final now = _clock.nowUtc();
    final operationId = _idGenerator.newId();
    final shouldAppendPrice = _priceChanged(existing.activePrice, draft.price);
    final priceId = shouldAppendPrice ? _idGenerator.newId() : null;
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _requireProductReferences(
          database: database,
          context: context,
          draft: draft,
        );
        final updated =
            await (database.update(database.products)..where(
                  (row) =>
                      row.id.equals(productId) &
                      row.organizationId.equals(context.organizationId),
                ))
                .write(
                  ProductsCompanion(
                    categoryId: Value(draft.categoryId),
                    unitId: Value(draft.unitId),
                    taxCategoryId: Value(draft.taxCategoryId),
                    sku: Value(draft.sku),
                    normalizedSku: Value(normalizedSku),
                    name: Value(draft.name),
                    normalizedName: Value(CatalogNormalizer.search(draft.name)),
                    description: Value(draft.description),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const AuthorizationFailure(
            'The product is not available in this organization.',
            code: 'cross-organization-reference',
          );
        }
        await _replaceBarcodes(
          database: database,
          context: context,
          productId: productId,
          barcodes: draft.barcodes,
          now: now,
        );
        if (shouldAppendPrice) {
          await _appendPrice(
            database: database,
            context: context,
            productId: productId,
            priceId: priceId,
            draft: draft.price,
            currentPrice: existing.activePrice,
            now: now,
          );
        }
        await _appendImages(
          database: database,
          context: context,
          productId: productId,
          paths: draft.imagePaths
              .where((path) => !existing.imagePaths.contains(path))
              .toList(growable: false),
          now: now,
        );
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'product',
        entityId: productId,
        metadata: {'sku': draft.sku, 'name': draft.name},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'product.update',
        aggregateType: 'product',
        aggregateId: productId,
        payload: _productPayload(productId, draft, priceId: priceId),
        now: now,
      ),
    );
  }

  @override
  Future<Result<String, Failure>> addProductPrice({
    required BusinessContext context,
    required String productId,
    required domain_price.ProductPriceDraft draft,
  }) async {
    final priceFailure = _priceScopeFailure(context: context, draft: draft);
    if (priceFailure != null) {
      return Result.failure(priceFailure);
    }
    final product = await getProduct(context: context, productId: productId);
    if (product == null) {
      return const Result.failure(
        AuthorizationFailure(
          'The product is not available in this organization.',
          code: 'cross-organization-reference',
        ),
      );
    }
    if (!_priceChanged(product.activePrice, draft)) {
      return Result.success(product.activePrice!.id);
    }
    final currentEffectiveFrom = product.activePrice?.effectiveFrom.toUtc();
    final requestedEffectiveFrom = draft.effectiveFrom?.toUtc();
    if (currentEffectiveFrom != null &&
        requestedEffectiveFrom != null &&
        !requestedEffectiveFrom.isAfter(currentEffectiveFrom)) {
      return const Result.failure(
        ValidationFailure(
          'A new effective price must start after the current price.',
        ),
      );
    }

    final priceId = _idGenerator.newId();
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _requireActiveBranch(database, context);
        final ownedProduct =
            await (database.select(database.products)..where(
                  (row) =>
                      row.id.equals(productId) &
                      row.organizationId.equals(context.organizationId),
                ))
                .getSingleOrNull();
        if (ownedProduct == null) {
          throw const AuthorizationFailure(
            'The product is not available in this organization.',
            code: 'cross-organization-reference',
          );
        }
        await _appendPrice(
          database: database,
          context: context,
          productId: productId,
          priceId: priceId,
          draft: draft,
          currentPrice: product.activePrice,
          now: now,
        );
        return priceId;
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.create,
        entityName: 'product_price',
        entityId: priceId,
        metadata: {
          'productId': productId,
          'scope': draft.scope.name,
          'unitPriceMinor': draft.unitPriceMinor,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'product_price.create',
        aggregateType: 'product_price',
        aggregateId: priceId,
        payload: {
          'id': priceId,
          'productId': productId,
          'scope': draft.scope.name,
          'branchId': draft.branchId,
          'unitPriceMinor': draft.unitPriceMinor,
          'effectiveFrom': draft.effectiveFrom?.toIso8601String(),
        },
        now: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> setProductArchived({
    required BusinessContext context,
    required String productId,
    required bool archived,
  }) {
    final now = _clock.nowUtc();
    final operationId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _requireActiveBranch(database, context);
        final updated =
            await (database.update(database.products)..where(
                  (row) =>
                      row.id.equals(productId) &
                      row.organizationId.equals(context.organizationId),
                ))
                .write(
                  ProductsCompanion(
                    isActive: Value(!archived),
                    deletedAt: Value(archived ? now : null),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const AuthorizationFailure(
            'The product is not available in this organization.',
            code: 'cross-organization-reference',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: archived ? AuditActionType.delete : AuditActionType.update,
        entityName: 'product',
        entityId: productId,
        metadata: {'archived': archived},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: archived ? 'product.archive' : 'product.restore',
        aggregateType: 'product',
        aggregateId: productId,
        payload: {'productId': productId, 'archived': archived},
        now: now,
      ),
    );
  }

  @override
  Future<Result<String, Failure>> createCategory({
    required BusinessContext context,
    required CategoryDraft draft,
  }) async {
    final normalizedName = CatalogNormalizer.search(draft.name);
    if (await _localDataSource.categoryNameExists(
      organizationId: context.organizationId,
      normalizedName: normalizedName,
    )) {
      return const Result.failure(
        ConflictFailure('A category with this name already exists.'),
      );
    }
    final id = _idGenerator.newId();
    final now = _clock.nowUtc();
    final operationId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _requireActiveBranch(database, context);
        await database
            .into(database.categories)
            .insert(
              CategoriesCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                name: draft.name,
                normalizedName: normalizedName,
                createdAt: now,
                updatedAt: now,
              ),
            );
        return id;
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.create,
        entityName: 'category',
        entityId: id,
        metadata: {'name': draft.name},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'category.create',
        aggregateType: 'category',
        aggregateId: id,
        payload: {'id': id, 'name': draft.name},
        now: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> updateCategory({
    required BusinessContext context,
    required String categoryId,
    required CategoryDraft draft,
  }) async {
    final normalizedName = CatalogNormalizer.search(draft.name);
    if (await _localDataSource.categoryNameExists(
      organizationId: context.organizationId,
      normalizedName: normalizedName,
      excludingCategoryId: categoryId,
    )) {
      return const Result.failure(
        ConflictFailure('A category with this name already exists.'),
      );
    }
    final now = _clock.nowUtc();
    final operationId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _requireActiveBranch(database, context);
        final updated =
            await (database.update(database.categories)..where(
                  (row) =>
                      row.id.equals(categoryId) &
                      row.organizationId.equals(context.organizationId),
                ))
                .write(
                  CategoriesCompanion(
                    name: Value(draft.name),
                    normalizedName: Value(normalizedName),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const AuthorizationFailure(
            'The category is not available in this organization.',
            code: 'cross-organization-reference',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'category',
        entityId: categoryId,
        metadata: {'name': draft.name},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'category.update',
        aggregateType: 'category',
        aggregateId: categoryId,
        payload: {'id': categoryId, 'name': draft.name},
        now: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> setCategoryArchived({
    required BusinessContext context,
    required String categoryId,
    required bool archived,
  }) {
    return _setCatalogRecordArchived(
      context: context,
      id: categoryId,
      archived: archived,
      entityName: 'category',
      write: (database, now) async {
        return (database.update(database.categories)..where(
              (row) =>
                  row.id.equals(categoryId) &
                  row.organizationId.equals(context.organizationId),
            ))
            .write(
              CategoriesCompanion(
                isActive: Value(!archived),
                deletedAt: Value(archived ? now : null),
                updatedAt: Value(now),
              ),
            );
      },
    );
  }

  @override
  Future<Result<String, Failure>> createUnit({
    required BusinessContext context,
    required UnitDraft draft,
  }) async {
    if (await _localDataSource.unitCodeExists(
      organizationId: context.organizationId,
      code: draft.code,
    )) {
      return const Result.failure(
        ConflictFailure('A unit with this code already exists.'),
      );
    }
    final id = _idGenerator.newId();
    final now = _clock.nowUtc();
    final operationId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _requireActiveBranch(database, context);
        await database
            .into(database.units)
            .insert(
              UnitsCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                code: draft.code,
                name: draft.name,
                abbreviation: draft.abbreviation,
                allowsFractional: Value(draft.allowsFractional),
                createdAt: now,
                updatedAt: now,
              ),
            );
        return id;
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.create,
        entityName: 'unit',
        entityId: id,
        metadata: {'code': draft.code, 'name': draft.name},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'unit.create',
        aggregateType: 'unit',
        aggregateId: id,
        payload: {
          'id': id,
          'code': draft.code,
          'name': draft.name,
          'abbreviation': draft.abbreviation,
          'allowsFractional': draft.allowsFractional,
        },
        now: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> updateUnit({
    required BusinessContext context,
    required String unitId,
    required UnitDraft draft,
  }) async {
    if (await _localDataSource.unitCodeExists(
      organizationId: context.organizationId,
      code: draft.code,
      excludingUnitId: unitId,
    )) {
      return const Result.failure(
        ConflictFailure('A unit with this code already exists.'),
      );
    }
    final now = _clock.nowUtc();
    final operationId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _requireActiveBranch(database, context);
        final updated =
            await (database.update(database.units)..where(
                  (row) =>
                      row.id.equals(unitId) &
                      row.organizationId.equals(context.organizationId),
                ))
                .write(
                  UnitsCompanion(
                    code: Value(draft.code),
                    name: Value(draft.name),
                    abbreviation: Value(draft.abbreviation),
                    allowsFractional: Value(draft.allowsFractional),
                    updatedAt: Value(now),
                  ),
                );
        if (updated != 1) {
          throw const AuthorizationFailure(
            'The unit is not available in this organization.',
            code: 'cross-organization-reference',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'unit',
        entityId: unitId,
        metadata: {'code': draft.code, 'name': draft.name},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'unit.update',
        aggregateType: 'unit',
        aggregateId: unitId,
        payload: {
          'id': unitId,
          'code': draft.code,
          'name': draft.name,
          'abbreviation': draft.abbreviation,
          'allowsFractional': draft.allowsFractional,
        },
        now: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> setUnitArchived({
    required BusinessContext context,
    required String unitId,
    required bool archived,
  }) {
    return _setCatalogRecordArchived(
      context: context,
      id: unitId,
      archived: archived,
      entityName: 'unit',
      write: (database, now) async {
        return (database.update(database.units)..where(
              (row) =>
                  row.id.equals(unitId) &
                  row.organizationId.equals(context.organizationId),
            ))
            .write(
              UnitsCompanion(
                isActive: Value(!archived),
                deletedAt: Value(archived ? now : null),
                updatedAt: Value(now),
              ),
            );
      },
    );
  }

  Future<Failure?> _duplicateFailure({
    required BusinessContext context,
    required String normalizedSku,
    required List<String> normalizedBarcodes,
    String? excludingProductId,
  }) async {
    if (await _localDataSource.skuExists(
      organizationId: context.organizationId,
      normalizedSku: normalizedSku,
      excludingProductId: excludingProductId,
    )) {
      return const ConflictFailure(
        'A product with this SKU already exists in the organization.',
      );
    }
    if (await _localDataSource.barcodeExists(
      organizationId: context.organizationId,
      normalizedBarcodes: normalizedBarcodes,
      excludingProductId: excludingProductId,
    )) {
      return const ConflictFailure(
        'One or more barcodes already belong to another product.',
      );
    }
    return null;
  }

  Future<Result<void, Failure>> _setCatalogRecordArchived({
    required BusinessContext context,
    required String id,
    required bool archived,
    required String entityName,
    required Future<int> Function(AppDatabase database, DateTime now) write,
  }) {
    final now = _clock.nowUtc();
    final operationId = _idGenerator.newId();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await _requireActiveBranch(database, context);
        if (await write(database, now) != 1) {
          throw AuthorizationFailure(
            'The $entityName is not available in this organization.',
            code: 'cross-organization-reference',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: archived ? AuditActionType.delete : AuditActionType.update,
        entityName: entityName,
        entityId: id,
        metadata: {'archived': archived},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: archived ? '$entityName.archive' : '$entityName.restore',
        aggregateType: entityName,
        aggregateId: id,
        payload: {'id': id, 'archived': archived},
        now: now,
      ),
    );
  }

  Future<void> _requireProductReferences({
    required AppDatabase database,
    required BusinessContext context,
    required ProductDraft draft,
  }) async {
    await _requireActiveBranch(database, context);
    final unit =
        await (database.select(database.units)..where(
              (row) =>
                  row.id.equals(draft.unitId) &
                  row.organizationId.equals(context.organizationId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (unit == null) {
      throw const AuthorizationFailure(
        'The selected unit is not active in this organization.',
        code: 'cross-organization-reference',
      );
    }

    final categoryId = draft.categoryId;
    if (categoryId != null) {
      final category =
          await (database.select(database.categories)..where(
                (row) =>
                    row.id.equals(categoryId) &
                    row.organizationId.equals(context.organizationId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (category == null) {
        throw const AuthorizationFailure(
          'The selected category is not active in this organization.',
          code: 'cross-organization-reference',
        );
      }
    }

    final taxCategoryId = draft.taxCategoryId;
    if (taxCategoryId != null) {
      final taxCategory =
          await (database.select(database.taxCategories)..where(
                (row) =>
                    row.id.equals(taxCategoryId) &
                    row.organizationId.equals(context.organizationId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (taxCategory == null) {
        throw const AuthorizationFailure(
          'The selected tax category is not active in this organization.',
          code: 'cross-organization-reference',
        );
      }
    }
  }

  Future<void> _requireActiveBranch(
    AppDatabase database,
    BusinessContext context,
  ) async {
    final branch =
        await (database.select(database.branches)..where(
              (row) =>
                  row.id.equals(context.branchId) &
                  row.organizationId.equals(context.organizationId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (branch == null) {
      throw const AuthorizationFailure(
        'The active branch is not available in this organization.',
        code: 'cross-organization-reference',
      );
    }
  }

  Failure? _priceScopeFailure({
    required BusinessContext context,
    required domain_price.ProductPriceDraft draft,
  }) {
    if (draft.scope == domain_price.PriceScope.organization &&
        draft.branchId != null) {
      return const ValidationFailure(
        'Organization pricing cannot target a branch.',
      );
    }
    if (draft.scope == domain_price.PriceScope.branch &&
        draft.branchId != context.branchId) {
      return const ValidationFailure(
        'Branch pricing can only target the active branch.',
      );
    }
    return null;
  }

  bool _priceChanged(
    domain_price.ProductPrice? current,
    domain_price.ProductPriceDraft draft,
  ) {
    if (current == null ||
        current.scope != draft.scope ||
        current.branchId != draft.branchId ||
        current.unitPriceMinor != draft.unitPriceMinor) {
      return true;
    }
    final requestedEffectiveFrom = draft.effectiveFrom?.toUtc();
    return requestedEffectiveFrom != null &&
        !requestedEffectiveFrom.isAtSameMomentAs(current.effectiveFrom.toUtc());
  }

  Future<void> _replaceBarcodes({
    required AppDatabase database,
    required BusinessContext context,
    required String productId,
    required List<String> barcodes,
    required DateTime now,
  }) async {
    final existing = await (database.select(
      database.productBarcodes,
    )..where((row) => row.productId.equals(productId))).get();
    final desired = <String, String>{
      for (final barcode in barcodes)
        CatalogNormalizer.barcode(barcode): barcode.trim(),
    };
    final primaryBarcode = barcodes.isEmpty
        ? null
        : CatalogNormalizer.barcode(barcodes.first);
    for (final row in existing) {
      final barcode = desired.remove(row.normalizedBarcode);
      await (database.update(
        database.productBarcodes,
      )..where((item) => item.id.equals(row.id))).write(
        ProductBarcodesCompanion(
          barcode: Value(barcode ?? row.barcode),
          isPrimary: Value(
            barcode != null && primaryBarcode == row.normalizedBarcode,
          ),
          deletedAt: Value(barcode == null ? now : null),
          updatedAt: Value(now),
        ),
      );
    }
    for (final entry in desired.entries) {
      await database
          .into(database.productBarcodes)
          .insert(
            ProductBarcodesCompanion.insert(
              id: _idGenerator.newId(),
              organizationId: context.organizationId,
              productId: productId,
              barcode: entry.value,
              normalizedBarcode: entry.key,
              isPrimary: Value(entry.key == primaryBarcode),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _appendPrice({
    required AppDatabase database,
    required BusinessContext context,
    required String productId,
    String? priceId,
    required domain_price.ProductPriceDraft draft,
    required domain_price.ProductPrice? currentPrice,
    required DateTime now,
  }) async {
    final branchId = draft.scope == domain_price.PriceScope.branch
        ? draft.branchId
        : null;
    final effectiveFrom = (draft.effectiveFrom ?? now).toUtc();
    final targetScope = database.update(database.productPrices)
      ..where(
        (row) =>
            row.productId.equals(productId) &
            row.organizationId.equals(context.organizationId) &
            (branchId == null
                ? row.branchId.isNull()
                : row.branchId.equals(branchId)) &
            row.effectiveFrom.isSmallerThanValue(effectiveFrom) &
            row.effectiveTo.isNull(),
      );
    await targetScope.write(
      ProductPricesCompanion(effectiveTo: Value(effectiveFrom)),
    );

    final closesPreviousBranchOverride =
        currentPrice != null &&
        currentPrice.scope == domain_price.PriceScope.branch &&
        draft.scope == domain_price.PriceScope.organization;
    if (closesPreviousBranchOverride) {
      await (database.update(database.productPrices)..where(
            (row) => row.id.equals(currentPrice.id) & row.effectiveTo.isNull(),
          ))
          .write(ProductPricesCompanion(effectiveTo: Value(effectiveFrom)));
    }
    await database
        .into(database.productPrices)
        .insert(
          ProductPricesCompanion.insert(
            id: priceId ?? _idGenerator.newId(),
            organizationId: context.organizationId,
            productId: productId,
            branchId: Value(branchId),
            branchScope: branchId ?? '*',
            unitPriceMinor: draft.unitPriceMinor,
            effectiveFrom: effectiveFrom,
            createdByUserId: context.actorUserId,
            createdAt: now,
          ),
        );
  }

  Future<void> _appendImages({
    required AppDatabase database,
    required BusinessContext context,
    required String productId,
    required List<String> paths,
    required DateTime now,
  }) async {
    for (var index = 0; index < paths.length; index++) {
      await database
          .into(database.productImages)
          .insert(
            ProductImagesCompanion.insert(
              id: _idGenerator.newId(),
              organizationId: context.organizationId,
              productId: productId,
              localPath: Value(paths[index]),
              sortOrder: Value(index),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  AuditLogEntry _audit({
    required BusinessContext context,
    required String operationId,
    required AuditActionType action,
    required String entityName,
    required String entityId,
    required Map<String, Object?> metadata,
    required DateTime now,
  }) {
    return AuditLogEntry(
      id: _idGenerator.newId(),
      operationId: operationId,
      organizationId: context.organizationId,
      actorUserId: context.actorUserId,
      branchId: context.branchId,
      actionType: action,
      entityName: entityName,
      entityId: entityId,
      metadata: metadata,
      createdAt: now,
    );
  }

  OutboxCommand _outbox({
    required BusinessContext context,
    required String operationId,
    required String commandType,
    required String aggregateType,
    required String aggregateId,
    required Map<String, Object?> payload,
    required DateTime now,
  }) {
    return OutboxCommand(
      operationId: operationId,
      organizationId: context.organizationId,
      branchId: context.branchId,
      actorUserId: context.actorUserId,
      commandType: commandType,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      payload: payload,
      createdAt: now,
    );
  }

  Map<String, Object?> _productPayload(
    String productId,
    ProductDraft draft, {
    String? priceId,
  }) {
    return {
      'id': productId,
      'sku': draft.sku,
      'name': draft.name,
      'description': draft.description,
      'categoryId': draft.categoryId,
      'unitId': draft.unitId,
      'taxCategoryId': draft.taxCategoryId,
      'barcodes': draft.barcodes,
      'imagePaths': draft.imagePaths,
      'unitPriceMinor': draft.unitPriceMinor,
      'priceId': priceId,
      'priceScope': draft.priceScope.name,
      'priceBranchId': draft.priceBranchId,
      'priceEffectiveFrom': draft.priceEffectiveFrom?.toIso8601String(),
    };
  }
}
