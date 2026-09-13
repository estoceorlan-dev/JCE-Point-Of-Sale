import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../shared/models/business_context.dart';
import '../database/app_database.dart';
import '../error/failure.dart';
import '../error/failure_mapper.dart';
import '../error/result.dart';
import '../remote/pos_bootstrap_remote_data_source.dart';
import 'pos_bootstrap_repository.dart';

class DriftPosBootstrapRepository implements PosBootstrapRepository {
  DriftPosBootstrapRepository({
    required AppDatabase database,
    required PosBootstrapRemoteDataSource remote,
  }) : _database = database,
       _remote = remote;

  static const collections = [
    'organization',
    'branch',
    'registers',
    'categories',
    'units',
    'taxCategories',
    'products',
    'productBarcodes',
    'productPrices',
    'stockLocations',
    'inventoryBalances',
    'organizationSettings',
    'branchSettings',
    'reasonCodes',
    'featureFlags',
  ];

  final AppDatabase _database;
  final PosBootstrapRemoteDataSource _remote;
  final Map<String, StreamController<PosBootstrapProgress>> _controllers = {};
  final Map<String, Future<Result<void, Failure>>> _activeRuns = {};

  @override
  Stream<PosBootstrapProgress> watchProgress(BusinessContext context) async* {
    final key = _scope(context);
    yield await _storedProgress(context);
    yield* _controllers
        .putIfAbsent(key, () => StreamController.broadcast())
        .stream;
  }

  @override
  Future<bool> hasUsableCache(BusinessContext context) async {
    if (await _database.metadataDao.readValue(_readyKey(context)) != null) {
      return true;
    }
    final branch =
        await (_database.select(_database.branches)
              ..where(
                (row) =>
                    row.id.equals(context.branchId) &
                    row.organizationId.equals(context.organizationId) &
                    row.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    final product =
        await (_database.select(_database.products)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    final location =
        await (_database.select(_database.stockLocations)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(context.branchId) &
                    row.isDefault.equals(true) &
                    row.isActive.equals(true) &
                    row.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (branch == null || product == null || location == null) return false;
    final now = DateTime.now().toUtc();
    await _database.metadataDao.writeValue(
      key: _readyKey(context),
      value: 'adopted:${now.toIso8601String()}',
      updatedAt: now,
    );
    return true;
  }

  @override
  Future<Result<void, Failure>> provision(
    BusinessContext context, {
    bool force = false,
  }) {
    final key = _scope(context);
    final active = _activeRuns[key];
    if (active != null) return active;
    final run = _provision(context, force: force);
    _activeRuns[key] = run;
    return run.whenComplete(() => _activeRuns.remove(key));
  }

  Future<Result<void, Failure>> _provision(
    BusinessContext context, {
    required bool force,
  }) async {
    try {
      if (!force && await hasUsableCache(context)) {
        _emit(
          context,
          const PosBootstrapProgress(status: PosBootstrapStatus.ready),
        );
        return const Result.success(null);
      }
      if (force) await _discardStaging(context);
      var snapshotToken = await _database.metadataDao.readValue(
        _tokenKey(context),
      );
      var completed = 0;
      _emit(
        context,
        const PosBootstrapProgress(status: PosBootstrapStatus.preparing),
      );
      for (final collection in collections) {
        final completedKey = _collectionCompleteKey(context, collection);
        if (await _database.metadataDao.readValue(completedKey) == 'true') {
          completed++;
          continue;
        }
        var cursor = await _database.metadataDao.readValue(
          _cursorKey(context, collection),
        );
        while (true) {
          final page = await _remote.fetchPage(
            organizationId: context.organizationId,
            branchId: context.branchId,
            collection: collection,
            snapshotToken: snapshotToken,
            cursor: cursor,
          );
          if (page.collection != collection ||
              (snapshotToken != null && page.snapshotToken != snapshotToken)) {
            throw const FormatException(
              'A POS bootstrap page changed snapshot scope.',
            );
          }
          final localChecksum = sha256
              .convert(
                utf8.encode(
                  jsonEncode({
                    'collection': collection,
                    'cursor': cursor ?? '',
                    'rows': page.rows,
                  }),
                ),
              )
              .toString();
          if (localChecksum != page.checksum) {
            throw const FormatException(
              'A POS bootstrap page failed checksum validation.',
            );
          }
          snapshotToken ??= page.snapshotToken;
          await _stagePage(context, page);
          cursor = page.nextCursor;
          if (page.complete) break;
          if (cursor == null || cursor.isEmpty) {
            throw const FormatException(
              'An incomplete POS bootstrap page has no cursor.',
            );
          }
        }
        completed++;
        _emit(
          context,
          PosBootstrapProgress(
            status: PosBootstrapStatus.preparing,
            collection: collection,
            completedCollections: completed,
          ),
        );
      }
      if (snapshotToken == null) {
        throw const FormatException(
          'POS bootstrap produced no snapshot token.',
        );
      }
      await _publish(context, snapshotToken);
      _emit(
        context,
        PosBootstrapProgress(
          status: PosBootstrapStatus.ready,
          completedCollections: collections.length,
        ),
      );
      return const Result.success(null);
    } catch (error, stackTrace) {
      final failure = FailureMapper.fromException(error, stackTrace);
      _emit(
        context,
        PosBootstrapProgress(
          status: PosBootstrapStatus.failed,
          message: failure.message,
        ),
      );
      return Result.failure(failure);
    }
  }

  Future<void> _stagePage(
    BusinessContext context,
    PosBootstrapPage page,
  ) async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      for (final row in page.rows) {
        final recordId = _requiredString(row, 'id');
        await _database
            .into(_database.syncSnapshotStagingRecords)
            .insertOnConflictUpdate(
              SyncSnapshotStagingRecordsCompanion.insert(
                snapshotToken: page.snapshotToken,
                organizationId: context.organizationId,
                branchId: context.branchId,
                collection: page.collection,
                recordId: recordId,
                payloadJson: jsonEncode(row),
                pageChecksum: page.checksum,
                watermark: page.watermark,
                stagedAt: now,
              ),
            );
      }
      await _database.metadataDao.writeValue(
        key: _tokenKey(context),
        value: page.snapshotToken,
        updatedAt: now,
      );
      if (page.complete) {
        await _database.metadataDao.writeValue(
          key: _collectionCompleteKey(context, page.collection),
          value: 'true',
          updatedAt: now,
        );
        await _database.metadataDao.deleteValue(
          _cursorKey(context, page.collection),
        );
      } else if (page.nextCursor != null) {
        await _database.metadataDao.writeValue(
          key: _cursorKey(context, page.collection),
          value: page.nextCursor!,
          updatedAt: now,
        );
      }
    });
  }

  Future<void> _publish(BusinessContext context, String token) async {
    final staged =
        await (_database.select(_database.syncSnapshotStagingRecords)..where(
              (row) =>
                  row.snapshotToken.equals(token) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId),
            ))
            .get();
    final byCollection = <String, List<Map<String, Object?>>>{};
    for (final record in staged) {
      byCollection
          .putIfAbsent(record.collection, () => [])
          .add(
            Map<String, Object?>.from(jsonDecode(record.payloadJson) as Map),
          );
    }
    if (!await _allCollectionsComplete(context)) {
      throw const FormatException('The staged POS snapshot is incomplete.');
    }
    final now = DateTime.now().toUtc();
    final preserveOperationalProjection = await _hasPendingOperationalChanges(
      context,
    );
    await _database.transaction(() async {
      for (final collection in collections) {
        for (final row in byCollection[collection] ?? const []) {
          await _applyRow(
            context,
            collection,
            row,
            preserveOperationalProjection: preserveOperationalProjection,
          );
        }
      }
      await _removeStaleRows(
        context,
        token,
        now,
        preserveOperationalProjection: preserveOperationalProjection,
      );
      await _database.metadataDao.writeValue(
        key: _readyKey(context),
        value: now.toIso8601String(),
        updatedAt: now,
      );
      await _database.metadataDao.writeValue(
        key: 'pos_bootstrap_watermark:${_scope(context)}',
        value: staged.isEmpty ? '0' : staged.first.watermark.toString(),
        updatedAt: now,
      );
      await (_database.delete(_database.syncSnapshotStagingRecords)..where(
            (row) =>
                row.organizationId.equals(context.organizationId) &
                row.branchId.equals(context.branchId),
          ))
          .go();
      await _clearProgressMetadata(context);
    });
  }

  Future<void> _applyRow(
    BusinessContext context,
    String collection,
    Map<String, Object?> row, {
    required bool preserveOperationalProjection,
  }) async {
    final id = _requiredString(row, 'id');
    final createdAt = _date(row['created_at']);
    final updatedAt = _date(row['updated_at']);
    switch (collection) {
      case 'organization':
        await _database
            .into(_database.organizations)
            .insertOnConflictUpdate(
              OrganizationsCompanion.insert(
                id: id,
                code: _requiredString(row, 'code'),
                name: _requiredString(row, 'name'),
                timezone: Value(_string(row['timezone']) ?? 'Asia/Manila'),
                isActive: Value(row['is_active'] == true),
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: Value(_nullableDate(row['deleted_at'])),
              ),
            );
      case 'branch':
        await _database
            .into(_database.branches)
            .insertOnConflictUpdate(
              BranchesCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                code: _requiredString(row, 'code'),
                name: _requiredString(row, 'name'),
                timezone: Value(_string(row['timezone']) ?? 'Asia/Manila'),
                addressLineOne: Value(_string(row['address_line_one'])),
                addressLineTwo: Value(_string(row['address_line_two'])),
                city: Value(_string(row['city'])),
                province: Value(_string(row['province'])),
                postalCode: Value(_string(row['postal_code'])),
                phone: Value(_string(row['phone'])),
                email: Value(_string(row['email'])),
                receiptDisplayName: Value(_string(row['receipt_display_name'])),
                isActive: Value(row['is_active'] == true),
                allowNegativeStock: Value(row['allow_negative_stock'] == true),
                adjustmentApprovalThresholdMilli: Value(
                  _nullableInt(row['adjustment_approval_threshold_milli']),
                ),
                allowMultipleOpenShiftsPerUser: Value(
                  row['allow_multiple_open_shifts_per_user'] == true,
                ),
                allowSalesWithoutOpenShift: Value(
                  row['allow_sales_without_open_shift'] == true,
                ),
                cashDiscrepancyApprovalThresholdMinor: Value(
                  _nullableInt(
                    row['cash_discrepancy_approval_threshold_minor'],
                  ),
                ),
                discountApprovalThresholdBasisPoints: Value(
                  _nullableInt(row['discount_approval_threshold_basis_points']),
                ),
                returnApprovalThresholdMinor: Value(
                  _nullableInt(row['return_approval_threshold_minor']),
                ),
                voidWindowMinutes: Value(
                  _nullableInt(row['void_window_minutes']) ?? 15,
                ),
                transferApprovalThresholdMilli: Value(
                  _nullableInt(row['transfer_approval_threshold_milli']),
                ),
                version: Value(_nullableInt(row['version']) ?? 0),
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: Value(_nullableDate(row['deleted_at'])),
              ),
            );
      case 'registers':
        if (await _hasPendingRegisterProjection(id)) return;
        await _database
            .into(_database.registers)
            .insertOnConflictUpdate(
              RegistersCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                branchId: context.branchId,
                code: _requiredString(row, 'code'),
                name: _requiredString(row, 'name'),
                assignedDeviceId: Value(_string(row['assigned_device_id'])),
                assignedByUserId: Value(_string(row['assigned_by_user_id'])),
                assignedAt: Value(_nullableDate(row['assigned_at'])),
                scannerType: Value(
                  _string(row['scanner_type']) ?? 'keyboard_wedge',
                ),
                scannerInterCharacterTimeoutMs: Value(
                  _nullableInt(row['scanner_inter_character_timeout_ms']) ?? 80,
                ),
                scannerDuplicateSuppressionMs: Value(
                  _nullableInt(row['scanner_duplicate_suppression_ms']) ?? 350,
                ),
                printerType: Value(_string(row['printer_type']) ?? 'screen'),
                printerAddress: Value(_string(row['printer_address'])),
                printerPort: Value(_nullableInt(row['printer_port']) ?? 9100),
                printerPaperWidthMm: Value(
                  _nullableInt(row['printer_paper_width_mm']) ?? 80,
                ),
                cashDrawerEnabled: Value(row['cash_drawer_enabled'] == true),
                cashDrawerPin: Value(_nullableInt(row['cash_drawer_pin']) ?? 0),
                isActive: Value(row['is_active'] == true),
                version: Value(_nullableInt(row['version']) ?? 0),
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: Value(_nullableDate(row['deleted_at'])),
              ),
            );
      case 'categories':
        if (await _hasPending('category', id)) return;
        await _database
            .into(_database.categories)
            .insertOnConflictUpdate(
              CategoriesCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                name: _requiredString(row, 'name'),
                normalizedName: _requiredString(row, 'normalized_name'),
                isActive: Value(row['is_active'] == true),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );
      case 'units':
        if (await _hasPending('unit', id)) return;
        await _database
            .into(_database.units)
            .insertOnConflictUpdate(
              UnitsCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                code: _requiredString(row, 'code'),
                name: _requiredString(row, 'name'),
                abbreviation: _requiredString(row, 'abbreviation'),
                allowsFractional: Value(row['allows_fractional'] == true),
                isActive: Value(row['is_active'] == true),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );
      case 'taxCategories':
        if (await _hasPending('tax_category', id)) return;
        await _database
            .into(_database.taxCategories)
            .insertOnConflictUpdate(
              TaxCategoriesCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                code: _requiredString(row, 'code'),
                name: _requiredString(row, 'name'),
                rateBasisPoints: _nullableInt(row['rate_basis_points']) ?? 0,
                isInclusive: Value(row['is_inclusive'] == true),
                isActive: Value(row['is_active'] == true),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );
      case 'products':
        if (await _hasPending('product', id)) return;
        await _database
            .into(_database.products)
            .insertOnConflictUpdate(
              ProductsCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                categoryId: Value(_string(row['category_id'])),
                unitId: _requiredString(row, 'unit_id'),
                taxCategoryId: Value(_string(row['tax_category_id'])),
                sku: _requiredString(row, 'sku'),
                normalizedSku: _requiredString(row, 'normalized_sku'),
                name: _requiredString(row, 'name'),
                normalizedName: _requiredString(row, 'normalized_name'),
                description: Value(_string(row['description'])),
                isActive: Value(row['is_active'] == true),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );
      case 'productBarcodes':
        if (await _hasPending('product', _requiredString(row, 'product_id'))) {
          return;
        }
        await _database
            .into(_database.productBarcodes)
            .insertOnConflictUpdate(
              ProductBarcodesCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                productId: _requiredString(row, 'product_id'),
                barcode: _requiredString(row, 'barcode'),
                normalizedBarcode: _requiredString(row, 'normalized_barcode'),
                isPrimary: Value(row['is_primary'] == true),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );
      case 'productPrices':
        if (await _hasPending('product', _requiredString(row, 'product_id'))) {
          return;
        }
        await _database
            .into(_database.productPrices)
            .insertOnConflictUpdate(
              ProductPricesCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                productId: _requiredString(row, 'product_id'),
                branchId: Value(_string(row['branch_id'])),
                branchScope: _requiredString(row, 'branch_scope'),
                unitPriceMinor: _nullableInt(row['unit_price_minor']) ?? 0,
                effectiveFrom: _date(row['effective_from']),
                effectiveTo: Value(_nullableDate(row['effective_to'])),
                createdByUserId: _requiredString(row, 'created_by_user_id'),
                createdAt: createdAt,
              ),
            );
      case 'stockLocations':
        if (await _hasPending('stock_location', id)) return;
        await _database
            .into(_database.stockLocations)
            .insertOnConflictUpdate(
              StockLocationsCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                branchId: context.branchId,
                code: _requiredString(row, 'code'),
                name: _requiredString(row, 'name'),
                locationType: Value(
                  _string(row['location_type']) ?? 'warehouse',
                ),
                isDefault: Value(row['is_default'] == true),
                isActive: Value(row['is_active'] == true),
                version: Value(_nullableInt(row['version']) ?? 0),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );
      case 'inventoryBalances':
        if (preserveOperationalProjection) return;
        await _database
            .into(_database.inventoryBalances)
            .insertOnConflictUpdate(
              InventoryBalancesCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                branchId: context.branchId,
                stockLocationId: _requiredString(row, 'stock_location_id'),
                productId: _requiredString(row, 'product_id'),
                onHandMilli: Value(_nullableInt(row['on_hand_milli']) ?? 0),
                reservedMilli: Value(_nullableInt(row['reserved_milli']) ?? 0),
                reorderPointMilli: Value(
                  _nullableInt(row['reorder_point_milli']) ?? 0,
                ),
                weightedAverageCostMinor: Value(
                  _nullableInt(row['weighted_average_cost_minor']) ?? 0,
                ),
                version: Value(_nullableInt(row['version']) ?? 0),
                updatedAt: updatedAt,
              ),
            );
      case 'organizationSettings':
        if (await _hasPending('organization_setting', id)) return;
        await _database
            .into(_database.organizationSettings)
            .insertOnConflictUpdate(
              OrganizationSettingsCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                settingKey: _requiredString(row, 'setting_key'),
                valueJson: jsonEncode(row['value_json']),
                version: Value(_nullableInt(row['version']) ?? 0),
                updatedByUserId: _requiredString(row, 'updated_by_user_id'),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );
      case 'branchSettings':
        if (await _hasPending('branch_setting', id)) return;
        await _database
            .into(_database.branchSettings)
            .insertOnConflictUpdate(
              BranchSettingsCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                branchId: context.branchId,
                settingKey: _requiredString(row, 'setting_key'),
                valueJson: jsonEncode(row['value_json']),
                version: Value(_nullableInt(row['version']) ?? 0),
                updatedByUserId: _requiredString(row, 'updated_by_user_id'),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );
      case 'reasonCodes':
        if (await _hasPending('reason_code', id)) return;
        await _database
            .into(_database.reasonCodes)
            .insertOnConflictUpdate(
              ReasonCodesCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                branchId: Value(_string(row['branch_id'])),
                branchScope: _requiredString(row, 'branch_scope'),
                category: _requiredString(row, 'category'),
                code: _requiredString(row, 'code'),
                label: _requiredString(row, 'label'),
                requiresNote: Value(row['requires_note'] == true),
                isActive: Value(row['is_active'] == true),
                sortOrder: Value(_nullableInt(row['sort_order']) ?? 0),
                version: Value(_nullableInt(row['version']) ?? 0),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );
      case 'featureFlags':
        if (await _hasPending('feature_flag', id)) return;
        await _database
            .into(_database.featureFlags)
            .insertOnConflictUpdate(
              FeatureFlagsCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                branchId: Value(_string(row['branch_id'])),
                branchScope: _requiredString(row, 'branch_scope'),
                flagKey: _requiredString(row, 'flag_key'),
                isEnabled: Value(row['is_enabled'] == true),
                configurationJson: Value(jsonEncode(row['configuration_json'])),
                version: Value(_nullableInt(row['version']) ?? 0),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );
    }
  }

  Future<void> _removeStaleRows(
    BusinessContext context,
    String token,
    DateTime now, {
    required bool preserveOperationalProjection,
  }) async {
    Future<void> remove(
      String table,
      String collection,
      String scope,
      List<Variable<Object>> scopeVariables, {
      String? pendingAggregateType,
      String pendingIdExpression = 'local.id',
    }) async {
      await _database.customUpdate(
        'DELETE FROM $table AS local WHERE $scope AND NOT EXISTS ('
        'SELECT 1 FROM sync_snapshot_staging_records staged '
        'WHERE staged.snapshot_token = ? AND staged.collection = ? '
        'AND staged.record_id = local.id) '
        '${pendingAggregateType == null ? '' : 'AND NOT EXISTS ('
                  'SELECT 1 FROM sync_outbox pending WHERE '
                  'pending.aggregate_type = ? AND '
                  'pending.aggregate_id = $pendingIdExpression AND '
                  "pending.status NOT IN ('succeeded', 'discarded'))"}',
        variables: [
          ...scopeVariables,
          Variable<String>(token),
          Variable<String>(collection),
          if (pendingAggregateType != null)
            Variable<String>(pendingAggregateType),
        ],
      );
    }

    if (!preserveOperationalProjection) {
      await remove(
        'inventory_balances',
        'inventoryBalances',
        'local.organization_id = ? AND local.branch_id = ?',
        [
          Variable<String>(context.organizationId),
          Variable<String>(context.branchId),
        ],
      );
    }
    await remove(
      'product_barcodes',
      'productBarcodes',
      'local.organization_id = ? AND local.deleted_at IS NULL',
      [Variable<String>(context.organizationId)],
      pendingAggregateType: 'product',
      pendingIdExpression: 'local.product_id',
    );
    await remove(
      'product_prices',
      'productPrices',
      'local.organization_id = ? AND (local.branch_id IS NULL OR local.branch_id = ?)',
      [
        Variable<String>(context.organizationId),
        Variable<String>(context.branchId),
      ],
      pendingAggregateType: 'product',
      pendingIdExpression: 'local.product_id',
    );
    await remove(
      'branch_settings',
      'branchSettings',
      'local.organization_id = ? AND local.branch_id = ?',
      [
        Variable<String>(context.organizationId),
        Variable<String>(context.branchId),
      ],
      pendingAggregateType: 'branch_setting',
    );
    await _database.customUpdate(
      'UPDATE products AS local SET is_active = 0, deleted_at = ?, updated_at = ? '
      'WHERE local.organization_id = ? AND local.deleted_at IS NULL '
      'AND NOT EXISTS (SELECT 1 FROM sync_snapshot_staging_records staged '
      "WHERE staged.snapshot_token = ? AND staged.collection = 'products' "
      'AND staged.record_id = local.id) '
      'AND NOT EXISTS (SELECT 1 FROM sync_outbox pending '
      "WHERE pending.aggregate_type = 'product' AND pending.aggregate_id = local.id "
      "AND pending.status NOT IN ('succeeded', 'discarded'))",
      variables: [
        Variable<DateTime>(now),
        Variable<DateTime>(now),
        Variable<String>(context.organizationId),
        Variable<String>(token),
      ],
    );
  }

  Future<bool> _hasPending(String type, String id) async =>
      await (_database.select(_database.syncOutboxEntries)
            ..where(
              (row) =>
                  row.aggregateType.equals(type) &
                  row.aggregateId.equals(id) &
                  row.status.isNotIn(['succeeded', 'discarded']),
            )
            ..limit(1))
          .getSingleOrNull() !=
      null;

  Future<bool> _hasPendingRegisterProjection(String registerId) async {
    if (await _hasPending('register', registerId)) return true;
    final localClaim =
        await (_database.select(_database.registerClaims)
              ..where(
                (row) =>
                    (row.requestedRegisterId.equals(registerId) |
                        row.resolvedRegisterId.equals(registerId)) &
                    row.status.isIn(['provisional', 'rejected']),
              )
              ..limit(1))
            .getSingleOrNull();
    return localClaim != null;
  }

  Future<bool> _hasPendingOperationalChanges(BusinessContext context) async {
    final pending =
        await (_database.select(_database.syncOutboxEntries)
              ..where(
                (row) =>
                    row.organizationId.equals(context.organizationId) &
                    row.branchId.equals(context.branchId) &
                    row.status.isNotIn(['succeeded', 'discarded']) &
                    row.commandType.isIn([
                      'sale.complete',
                      'sale.return',
                      'sale.void',
                      'shift.open',
                      'shift.cash_movement',
                      'shift.close',
                      'inventory.adjust',
                      'stock_count.complete',
                    ]),
              )
              ..limit(1))
            .getSingleOrNull();
    return pending != null;
  }

  Future<bool> _allCollectionsComplete(BusinessContext context) async {
    for (final collection in collections) {
      if (await _database.metadataDao.readValue(
            _collectionCompleteKey(context, collection),
          ) !=
          'true') {
        return false;
      }
    }
    return true;
  }

  Future<void> _discardStaging(BusinessContext context) async {
    await _database.transaction(() async {
      await (_database.delete(_database.syncSnapshotStagingRecords)..where(
            (row) =>
                row.organizationId.equals(context.organizationId) &
                row.branchId.equals(context.branchId),
          ))
          .go();
      await _clearProgressMetadata(context);
    });
  }

  Future<void> _clearProgressMetadata(BusinessContext context) async {
    await _database.metadataDao.deleteValue(_tokenKey(context));
    for (final collection in collections) {
      await _database.metadataDao.deleteValue(_cursorKey(context, collection));
      await _database.metadataDao.deleteValue(
        _collectionCompleteKey(context, collection),
      );
    }
  }

  Future<PosBootstrapProgress> _storedProgress(BusinessContext context) async {
    if (await hasUsableCache(context)) {
      return const PosBootstrapProgress(status: PosBootstrapStatus.ready);
    }
    var completed = 0;
    for (final collection in collections) {
      if (await _database.metadataDao.readValue(
            _collectionCompleteKey(context, collection),
          ) ==
          'true') {
        completed++;
      }
    }
    return PosBootstrapProgress(
      status: completed == 0
          ? PosBootstrapStatus.notProvisioned
          : PosBootstrapStatus.preparing,
      completedCollections: completed,
    );
  }

  void _emit(BusinessContext context, PosBootstrapProgress progress) {
    _controllers[_scope(context)]?.add(progress);
  }

  String _scope(BusinessContext context) =>
      '${context.organizationId}:${context.branchId}';
  String _readyKey(BusinessContext context) =>
      'pos_bootstrap_ready:${_scope(context)}';
  String _tokenKey(BusinessContext context) =>
      'pos_bootstrap_token:${_scope(context)}';
  String _cursorKey(BusinessContext context, String collection) =>
      'pos_bootstrap_cursor:${_scope(context)}:$collection';
  String _collectionCompleteKey(BusinessContext context, String collection) =>
      'pos_bootstrap_complete:${_scope(context)}:$collection';
}

String _requiredString(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('POS bootstrap record is missing $key.');
  }
  return value;
}

String? _string(Object? value) => value?.toString();

int? _nullableInt(Object? value) => value is num
    ? value.toInt()
    : value == null
    ? null
    : int.tryParse(value.toString());

DateTime _date(Object? value) => DateTime.parse(value.toString()).toUtc();

DateTime? _nullableDate(Object? value) => value == null ? null : _date(value);
