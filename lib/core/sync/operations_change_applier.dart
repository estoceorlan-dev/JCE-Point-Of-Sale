import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../remote/remote_sync_data_source.dart';
import 'remote_change_envelope.dart';

class OperationsChangeApplier {
  const OperationsChangeApplier(this.database);

  final AppDatabase database;

  Future<bool> apply(RemoteChangeEnvelope envelope) async {
    final type = envelope.commandType;
    if (type.startsWith('branch.')) {
      await _branch(envelope);
    } else if (type == 'stock_location.create') {
      await _stockLocation(envelope);
    } else if (type.startsWith('inventory.')) {
      await _inventory(envelope);
    } else if (type.startsWith('register.')) {
      await _register(envelope);
    } else if (type.startsWith('shift.')) {
      await _shift(envelope);
    } else if (type.startsWith('stock_count.')) {
      await _stockCount(envelope);
    } else if (type == 'sale.complete') {
      await _sale(envelope);
    } else if (type == 'sale.return' || type == 'sale.void') {
      await _saleCorrection(envelope);
    } else if (type.startsWith('transfer.')) {
      await _transfer(envelope);
    } else if (type.startsWith('supplier.')) {
      await _supplier(envelope);
    } else if (type.startsWith('purchase_order.')) {
      await _purchaseOrder(envelope);
    } else if (type.startsWith('customer.') || type.startsWith('loyalty.')) {
      await _customer(envelope);
    } else if (type.startsWith('setting.') ||
        type.startsWith('reason_code.') ||
        type.startsWith('feature_flag.')) {
      await _settings(envelope);
    } else if (type == 'device.register') {
      // Device registration has no local business projection.
    } else {
      return false;
    }
    return true;
  }

  Future<void> _settings(RemoteChangeEnvelope envelope) async {
    final type = envelope.commandType;
    if (type == 'setting.branch.delete') {
      await (database.delete(database.branchSettings)..where(
            (row) =>
                row.id.equals(envelope.change.aggregateId) &
                row.organizationId.equals(envelope.change.organizationId),
          ))
          .go();
      await _applySettingProjection(
        envelope,
        _requiredString(envelope.commandPayload, 'key'),
        await _inheritedSettingValue(envelope),
      );
      return;
    }
    if (type == 'setting.organization.upsert' ||
        type == 'setting.branch.upsert') {
      final row = _requiredMap(envelope.result['setting'], 'setting');
      final id = envelope.change.aggregateId;
      final key = _requiredString(row, 'key');
      final value = row['value'];
      final now = _date(row['updatedAt']) ?? envelope.change.occurredAt;
      final createdAt = _date(row['createdAt']) ?? now;
      final version = _integer(row['version']);
      if (type == 'setting.organization.upsert') {
        await database
            .into(database.organizationSettings)
            .insertOnConflictUpdate(
              OrganizationSettingsCompanion.insert(
                id: id,
                organizationId: envelope.change.organizationId,
                settingKey: key,
                valueJson: jsonEncode(value),
                version: Value(version),
                updatedByUserId:
                    _string(row['updatedByUserId']) ?? envelope.actorUserId,
                createdAt: createdAt,
                updatedAt: now,
              ),
            );
        final override =
            await (database.select(database.branchSettings)..where(
                  (candidate) =>
                      candidate.organizationId.equals(
                        envelope.change.organizationId,
                      ) &
                      candidate.branchId.equals(
                        envelope.change.branchId ?? '',
                      ) &
                      candidate.settingKey.equals(key),
                ))
                .getSingleOrNull();
        if (override == null) {
          await _applySettingProjection(envelope, key, value);
        }
      } else {
        final branchId = _string(row['branchId']) ?? _branchId(envelope);
        await database
            .into(database.branchSettings)
            .insertOnConflictUpdate(
              BranchSettingsCompanion.insert(
                id: id,
                organizationId: envelope.change.organizationId,
                branchId: branchId,
                settingKey: key,
                valueJson: jsonEncode(value),
                version: Value(version),
                updatedByUserId:
                    _string(row['updatedByUserId']) ?? envelope.actorUserId,
                createdAt: createdAt,
                updatedAt: now,
              ),
            );
        await _applySettingProjection(envelope, key, value);
      }
      return;
    }
    if (type == 'reason_code.upsert') {
      final row = _requiredMap(envelope.result['reasonCode'], 'reasonCode');
      final branchId = _string(row['branchId']);
      final now = _date(row['updatedAt']) ?? envelope.change.occurredAt;
      await database
          .into(database.reasonCodes)
          .insertOnConflictUpdate(
            ReasonCodesCompanion.insert(
              id: envelope.change.aggregateId,
              organizationId: envelope.change.organizationId,
              branchId: Value(branchId),
              branchScope: branchId ?? '*',
              category: _requiredString(row, 'category'),
              code: _requiredString(row, 'code'),
              label: _requiredString(row, 'label'),
              requiresNote: Value(row['requiresNote'] == true),
              isActive: Value(row['isActive'] == true),
              sortOrder: Value(_integer(row['sortOrder'])),
              version: Value(_integer(row['version'])),
              createdAt: _date(row['createdAt']) ?? now,
              updatedAt: now,
            ),
          );
      return;
    }
    if (type == 'feature_flag.upsert') {
      final row = _requiredMap(envelope.result['featureFlag'], 'featureFlag');
      final branchId = _string(row['branchId']);
      final now = _date(row['updatedAt']) ?? envelope.change.occurredAt;
      await database
          .into(database.featureFlags)
          .insertOnConflictUpdate(
            FeatureFlagsCompanion.insert(
              id: envelope.change.aggregateId,
              organizationId: envelope.change.organizationId,
              branchId: Value(branchId),
              branchScope: branchId ?? '*',
              flagKey: _requiredString(row, 'key'),
              isEnabled: Value(row['isEnabled'] == true),
              configurationJson: Value(jsonEncode(row['configuration'] ?? {})),
              version: Value(_integer(row['version'])),
              createdAt: _date(row['createdAt']) ?? now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<Object?> _inheritedSettingValue(RemoteChangeEnvelope envelope) async {
    final key = _requiredString(envelope.commandPayload, 'key');
    final organization =
        await (database.select(database.organizationSettings)..where(
              (row) =>
                  row.organizationId.equals(envelope.change.organizationId) &
                  row.settingKey.equals(key),
            ))
            .getSingleOrNull();
    if (organization != null) return jsonDecode(organization.valueJson);
    return switch (key) {
      'inventory.allow_negative_stock' ||
      'shifts.allow_multiple_open_per_user' ||
      'shifts.allow_sales_without_open_shift' => false,
      'returns.void_window_minutes' => 15,
      _ => null,
    };
  }

  Future<void> _applySettingProjection(
    RemoteChangeEnvelope envelope,
    String key,
    Object? value,
  ) async {
    final branchId = envelope.change.branchId;
    final updatedAt = Value(envelope.change.occurredAt);
    final companion = switch (key) {
      'inventory.allow_negative_stock' => BranchesCompanion(
        allowNegativeStock: Value(value == true),
        updatedAt: updatedAt,
      ),
      'inventory.adjustment_approval_threshold_milli' => BranchesCompanion(
        adjustmentApprovalThresholdMilli: Value(_nullableInt(value)),
        updatedAt: updatedAt,
      ),
      'sales.discount_approval_threshold_basis_points' => BranchesCompanion(
        discountApprovalThresholdBasisPoints: Value(_nullableInt(value)),
        updatedAt: updatedAt,
      ),
      'shifts.allow_multiple_open_per_user' => BranchesCompanion(
        allowMultipleOpenShiftsPerUser: Value(value == true),
        updatedAt: updatedAt,
      ),
      'shifts.allow_sales_without_open_shift' => BranchesCompanion(
        allowSalesWithoutOpenShift: Value(value == true),
        updatedAt: updatedAt,
      ),
      'shifts.cash_discrepancy_approval_threshold_minor' => BranchesCompanion(
        cashDiscrepancyApprovalThresholdMinor: Value(_nullableInt(value)),
        updatedAt: updatedAt,
      ),
      'returns.approval_threshold_minor' => BranchesCompanion(
        returnApprovalThresholdMinor: Value(_nullableInt(value)),
        updatedAt: updatedAt,
      ),
      'returns.void_window_minutes' => BranchesCompanion(
        voidWindowMinutes: Value(_integer(value)),
        updatedAt: updatedAt,
      ),
      'transfers.approval_threshold_milli' => BranchesCompanion(
        transferApprovalThresholdMilli: Value(_nullableInt(value)),
        updatedAt: updatedAt,
      ),
      _ => null,
    };
    if (companion == null) return;
    final update = database.update(database.branches)
      ..where(
        (row) => row.organizationId.equals(envelope.change.organizationId),
      );
    if (branchId != null) {
      update.where((row) => row.id.equals(branchId));
    } else {
      final overrides =
          await (database.select(database.branchSettings)..where(
                (row) =>
                    row.organizationId.equals(envelope.change.organizationId) &
                    row.settingKey.equals(key),
              ))
              .get();
      final ids = overrides.map((row) => row.branchId).toList();
      if (ids.isNotEmpty) update.where((row) => row.id.isNotIn(ids));
    }
    await update.write(companion);
  }

  Future<void> _branch(RemoteChangeEnvelope envelope) async {
    final payload = envelope.commandPayload;
    final update = BranchesCompanion(
      updatedAt: Value(envelope.change.occurredAt),
    );
    switch (envelope.commandType) {
      case 'branch.update_name':
        await _updateBranch(
          envelope,
          update.copyWith(name: Value(_requiredString(payload, 'name'))),
        );
      case 'branch.shift_policy.update':
        await _updateBranch(
          envelope,
          update.copyWith(
            allowMultipleOpenShiftsPerUser: Value(
              payload['allowMultipleOpenShiftsPerUser'] == true,
            ),
            allowSalesWithoutOpenShift: Value(
              payload['allowSalesWithoutOpenShift'] == true,
            ),
            cashDiscrepancyApprovalThresholdMinor: Value(
              _nullableInt(payload['cashDiscrepancyApprovalThresholdMinor']),
            ),
          ),
        );
      case 'branch.discount_policy.update':
        await _updateBranch(
          envelope,
          update.copyWith(
            discountApprovalThresholdBasisPoints: Value(
              _nullableInt(payload['approvalThresholdBasisPoints']),
            ),
          ),
        );
      case 'branch.correction_policy.update':
        await _updateBranch(
          envelope,
          update.copyWith(
            returnApprovalThresholdMinor: Value(
              _nullableInt(payload['returnApprovalThresholdMinor']),
            ),
            voidWindowMinutes: Value(_integer(payload['voidWindowMinutes'])),
          ),
        );
      case 'branch.transfer_policy.configure':
        await _updateBranch(
          envelope,
          update.copyWith(
            transferApprovalThresholdMilli: Value(
              _nullableInt(payload['approvalThresholdMilli']),
            ),
          ),
        );
      case 'inventory.policy.configure':
        await _updateBranch(
          envelope,
          update.copyWith(
            allowNegativeStock: Value(payload['allowNegativeStock'] == true),
            adjustmentApprovalThresholdMilli: Value(
              _nullableInt(payload['adjustmentApprovalThresholdMilli']),
            ),
          ),
        );
    }
  }

  Future<void> _updateBranch(
    RemoteChangeEnvelope envelope,
    BranchesCompanion companion,
  ) async {
    final updated =
        await (database.update(database.branches)..where(
              (row) =>
                  row.id.equals(envelope.change.aggregateId) &
                  row.organizationId.equals(envelope.change.organizationId),
            ))
            .write(companion);
    if (updated != 1) {
      throw const FormatException('Remote branch is not available locally.');
    }
  }

  Future<void> _stockLocation(RemoteChangeEnvelope envelope) async {
    final row = _requiredMap(envelope.result['stockLocation'], 'stockLocation');
    final payload = envelope.commandPayload;
    final id = envelope.change.aggregateId;
    final existing = await (database.select(
      database.stockLocations,
    )..where((value) => value.id.equals(id))).getSingleOrNull();
    if (row['is_default'] == true || payload['isDefault'] == true) {
      await (database.update(database.stockLocations)..where(
            (value) =>
                value.organizationId.equals(envelope.change.organizationId) &
                value.branchId.equals(envelope.change.branchId ?? ''),
          ))
          .write(const StockLocationsCompanion(isDefault: Value(false)));
    }
    final now = envelope.change.occurredAt;
    await database
        .into(database.stockLocations)
        .insertOnConflictUpdate(
          StockLocationsCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            branchId: _branchId(envelope),
            code: _string(row['code']) ?? _requiredString(payload, 'code'),
            name: _string(row['name']) ?? _requiredString(payload, 'name'),
            locationType: Value(
              _string(row['location_type']) ??
                  _requiredString(payload, 'locationType'),
            ),
            isDefault: Value(
              row['is_default'] == true || payload['isDefault'] == true,
            ),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
  }

  Future<void> _inventory(RemoteChangeEnvelope envelope) async {
    if (envelope.commandType == 'inventory.policy.configure') {
      await _branch(envelope);
      return;
    }
    if (envelope.commandType == 'inventory.reorder_point.set') {
      await _applyBalance(
        envelope,
        _requiredMap(envelope.result['balance'], 'balance'),
        stockLocationId: _requiredString(
          envelope.commandPayload,
          'stockLocationId',
        ),
        productId: _requiredString(envelope.commandPayload, 'productId'),
      );
      return;
    }
    final result = envelope.result;
    await _applyInventoryTransaction(
      envelope,
      result: result,
      payload: envelope.commandPayload,
      operationId: envelope.change.operationId,
    );
  }

  Future<String?> _applyInventoryTransaction(
    RemoteChangeEnvelope envelope, {
    required Map<String, Object?> result,
    required Map<String, Object?> payload,
    required String operationId,
  }) async {
    final transaction = _map(result['inventoryTransaction']);
    if (transaction == null) return null;
    final id = _requiredString(transaction, 'id');
    final existing = await (database.select(
      database.inventoryTransactions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    final occurredAt =
        _date(transaction['occurredAt']) ??
        _date(payload['occurredAt']) ??
        envelope.change.occurredAt;
    await database
        .into(database.inventoryTransactions)
        .insertOnConflictUpdate(
          InventoryTransactionsCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            branchId: _branchId(envelope),
            operationId: existing?.operationId ?? operationId,
            transactionType:
                _string(transaction['transactionType']) ??
                _requiredString(payload, 'transactionType'),
            status: Value(_string(transaction['status']) ?? 'posted'),
            reasonCode: Value(_string(payload['reasonCode'])),
            notes: Value(_string(payload['notes'])),
            referenceType: Value(_string(payload['referenceType'])),
            referenceId: Value(_string(payload['referenceId'])),
            reversesTransactionId: Value(
              _string(payload['reversesTransactionId']),
            ),
            createdByUserId: envelope.actorUserId,
            approvedByUserId: Value(_string(payload['approvedByUserId'])),
            occurredAt: occurredAt,
            createdAt: existing?.createdAt ?? envelope.change.occurredAt,
          ),
        );

    final lines = payload['lines'] ?? result['lines'];
    final balances = result['balances'];
    if (lines is List && balances is List) {
      for (var index = 0; index < lines.length; index++) {
        final line = _requiredMap(lines[index], 'inventory line');
        final stockLocationId = _requiredString(line, 'stockLocationId');
        final productId = _requiredString(line, 'productId');
        final balance = balances
            .map((value) => _requiredMap(value, 'balance'))
            .where(
              (value) =>
                  value['stockLocationId'] == stockLocationId &&
                  value['productId'] == productId,
            )
            .firstOrNull;
        if (balance == null) continue;
        await _applyBalance(
          envelope,
          balance,
          stockLocationId: stockLocationId,
          productId: productId,
        );
        if (existing == null) {
          await database
              .into(database.inventoryLedgerEntries)
              .insert(
                InventoryLedgerEntriesCompanion.insert(
                  id: 'sync:${envelope.change.operationId}:inventory:$index',
                  organizationId: envelope.change.organizationId,
                  branchId: _branchId(envelope),
                  transactionId: id,
                  stockLocationId: stockLocationId,
                  productId: productId,
                  quantityDeltaMilli: _integer(line['quantityDeltaMilli']),
                  balanceAfterMilli: _integer(balance['onHandMilli']),
                  occurredAt: occurredAt,
                  createdAt: envelope.change.occurredAt,
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }
    }
    final reversedId = _string(result['reversedTransactionId']);
    if (reversedId != null) {
      await (database.update(
        database.inventoryTransactions,
      )..where((row) => row.id.equals(reversedId))).write(
        const InventoryTransactionsCompanion(status: Value('reversed')),
      );
    }
    return id;
  }

  Future<void> _applyBalance(
    RemoteChangeEnvelope envelope,
    Map<String, Object?> value, {
    required String stockLocationId,
    required String productId,
  }) async {
    final existing =
        await (database.select(database.inventoryBalances)..where(
              (row) =>
                  row.organizationId.equals(envelope.change.organizationId) &
                  row.branchId.equals(_branchId(envelope)) &
                  row.stockLocationId.equals(stockLocationId) &
                  row.productId.equals(productId),
            ))
            .getSingleOrNull();
    await database
        .into(database.inventoryBalances)
        .insertOnConflictUpdate(
          InventoryBalancesCompanion.insert(
            id: existing?.id ?? _requiredString(value, 'id'),
            organizationId: envelope.change.organizationId,
            branchId: _branchId(envelope),
            stockLocationId: stockLocationId,
            productId: productId,
            onHandMilli: Value(
              _integer(value['onHandMilli'] ?? value['on_hand_milli']),
            ),
            reservedMilli: Value(
              _nullableInt(value['reservedMilli']) ??
                  existing?.reservedMilli ??
                  0,
            ),
            reorderPointMilli: Value(
              _nullableInt(
                    value['reorder_point_milli'] ?? value['reorderPointMilli'],
                  ) ??
                  existing?.reorderPointMilli ??
                  0,
            ),
            weightedAverageCostMinor: Value(
              _nullableInt(value['weightedAverageCostMinor']) ??
                  existing?.weightedAverageCostMinor ??
                  0,
            ),
            version: Value(_integer(value['version'])),
            updatedAt: envelope.change.occurredAt,
          ),
        );
  }

  Future<void> _register(RemoteChangeEnvelope envelope) async {
    final row = _requiredMap(envelope.result['register'], 'register');
    final payload = envelope.commandPayload;
    final id = envelope.change.aggregateId;
    final existing = await (database.select(
      database.registers,
    )..where((value) => value.id.equals(id))).getSingleOrNull();
    final now = envelope.change.occurredAt;
    await database
        .into(database.registers)
        .insertOnConflictUpdate(
          RegistersCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            branchId: _branchId(envelope),
            code: _string(row['code']) ?? existing?.code ?? 'REGISTER',
            name: _string(row['name']) ?? existing?.name ?? 'Register',
            assignedDeviceId: Value(
              _string(row['assigned_device_id']) ??
                  _string(payload['deviceId']) ??
                  existing?.assignedDeviceId,
            ),
            assignedByUserId: Value(
              existing?.assignedByUserId ?? envelope.actorUserId,
            ),
            assignedAt: Value(existing?.assignedAt ?? now),
            isActive: Value(
              row['is_active'] as bool? ?? existing?.isActive ?? true,
            ),
            version: Value(
              _nullableInt(row['version']) ?? existing?.version ?? 0,
            ),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
  }

  Future<void> _shift(RemoteChangeEnvelope envelope) async {
    if (envelope.commandType == 'shift.cash_movement') {
      _requiredMap(envelope.result['cashMovement'], 'cashMovement');
      final payload = envelope.commandPayload;
      await database
          .into(database.cashMovements)
          .insert(
            CashMovementsCompanion.insert(
              id: envelope.change.aggregateId,
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              registerId: _requiredString(payload, 'registerId'),
              shiftId: _requiredString(payload, 'shiftId'),
              operationId: envelope.change.operationId,
              movementType: _requiredString(payload, 'movementType'),
              amountMinor: _integer(payload['amountMinor']),
              reason: _requiredString(payload, 'reason'),
              createdByUserId: envelope.actorUserId,
              approvedByUserId: Value(_string(payload['approvedByUserId'])),
              occurredAt:
                  _date(payload['occurredAt']) ?? envelope.change.occurredAt,
              createdAt: envelope.change.occurredAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      return;
    }
    final row = _requiredMap(envelope.result['shift'], 'shift');
    final payload = envelope.commandPayload;
    final id = envelope.change.aggregateId;
    final existing = await (database.select(
      database.shifts,
    )..where((value) => value.id.equals(id))).getSingleOrNull();
    if (existing == null && envelope.commandType == 'shift.open') {
      final now = envelope.change.occurredAt;
      await database
          .into(database.shifts)
          .insert(
            ShiftsCompanion.insert(
              id: id,
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              registerId: _requiredString(payload, 'registerId'),
              deviceId: _requiredString(payload, 'deviceId'),
              operationId: envelope.change.operationId,
              openingCashMinor: _integer(payload['openingCashMinor']),
              openingNotes: Value(_string(payload['notes'])),
              openedByUserId: envelope.actorUserId,
              openedAt:
                  _date(row['openedAt']) ?? _date(payload['openedAt']) ?? now,
              version: Value(_nullableInt(row['version']) ?? 0),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return;
    }
    if (existing != null && envelope.commandType == 'shift.close') {
      await (database.update(
        database.shifts,
      )..where((value) => value.id.equals(id))).write(
        ShiftsCompanion(
          closeOperationId: Value(envelope.change.operationId),
          status: const Value('closed'),
          expectedCashMinor: Value(
            _nullableInt(
              row['expected_cash_minor'] ?? row['expectedCashMinor'],
            ),
          ),
          countedCashMinor: Value(
            _nullableInt(
                  row['counted_cash_minor'] ?? row['countedCashMinor'],
                ) ??
                _integer(
                  _requiredMap(
                    payload['countedAmountsMinor'],
                    'countedAmountsMinor',
                  )['cash'],
                ),
          ),
          discrepancyMinor: Value(
            _nullableInt(row['discrepancy_minor'] ?? row['discrepancyMinor']),
          ),
          closingNotes: Value(_string(payload['notes'])),
          closedByUserId: Value(envelope.actorUserId),
          closedAt: Value(
            _date(row['closed_at'] ?? row['closedAt']) ??
                envelope.change.occurredAt,
          ),
          approvedByUserId: Value(_string(payload['approvedByUserId'])),
          approvedAt: Value(
            _string(payload['approvedByUserId']) == null
                ? null
                : envelope.change.occurredAt,
          ),
          approvalNotes: Value(_string(payload['approvalNotes'])),
          version: Value(_nullableInt(row['version']) ?? existing.version),
          updatedAt: Value(envelope.change.occurredAt),
        ),
      );
      final expected = _requiredMap(
        envelope.result['expectedByPaymentMethod'],
        'expectedByPaymentMethod',
      );
      final counted = _requiredMap(
        payload['countedAmountsMinor'],
        'countedAmountsMinor',
      );
      for (final (index, method) in const [
        'cash',
        'card',
        'e_wallet',
      ].indexed) {
        final expectedAmount = _integer(expected[method]);
        final countedAmount = _integer(counted[method]);
        await database
            .into(database.shiftCounts)
            .insert(
              ShiftCountsCompanion.insert(
                id: 'sync:${envelope.change.operationId}:count:$index',
                organizationId: envelope.change.organizationId,
                branchId: _branchId(envelope),
                shiftId: id,
                paymentMethod: method,
                expectedAmountMinor: expectedAmount,
                countedAmountMinor: countedAmount,
                discrepancyMinor: countedAmount - expectedAmount,
                countedByUserId: envelope.actorUserId,
                countedAt:
                    _date(payload['closedAt']) ?? envelope.change.occurredAt,
                createdAt: envelope.change.occurredAt,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    }
  }

  Future<void> _stockCount(RemoteChangeEnvelope envelope) async {
    final result = envelope.result;
    final payload = envelope.commandPayload;
    final countRow = _map(result['stockCount']);
    if (envelope.commandType == 'stock_count.start' && countRow != null) {
      final id = envelope.change.aggregateId;
      final now = envelope.change.occurredAt;
      await database
          .into(database.stockCounts)
          .insert(
            StockCountsCompanion.insert(
              id: id,
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              stockLocationId: _requiredString(payload, 'stockLocationId'),
              operationId: envelope.change.operationId,
              countType: _requiredString(payload, 'countType'),
              notes: Value(_string(payload['notes'])),
              startedByUserId: envelope.actorUserId,
              startedAt: _date(countRow['startedAt']) ?? now,
              version: Value(_nullableInt(countRow['version']) ?? 0),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      final items = result['items'];
      if (items is List) {
        for (final value in items) {
          final item = _requiredMap(value, 'stock count item');
          await database
              .into(database.stockCountItems)
              .insert(
                StockCountItemsCompanion.insert(
                  id: _requiredString(item, 'id'),
                  organizationId: envelope.change.organizationId,
                  stockCountId: id,
                  productId: _requiredString(item, 'productId'),
                  expectedQuantityMilli: _integer(
                    item['expectedQuantityMilli'],
                  ),
                  createdAt: now,
                  updatedAt: now,
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }
      return;
    }
    if (envelope.commandType == 'stock_count.item.record') {
      final item = _requiredMap(result['stockCountItem'], 'stockCountItem');
      await (database.update(database.stockCountItems)
            ..where((row) => row.id.equals(_requiredString(payload, 'itemId'))))
          .write(
            StockCountItemsCompanion(
              countedQuantityMilli: Value(
                _integer(item['counted_quantity_milli']),
              ),
              varianceQuantityMilli: Value(
                _integer(item['variance_quantity_milli']),
              ),
              countedByUserId: Value(envelope.actorUserId),
              countedAt: Value(envelope.change.occurredAt),
              version: Value(_integer(item['version'])),
              updatedAt: Value(envelope.change.occurredAt),
            ),
          );
      return;
    }
    if (countRow != null) {
      await (database.update(
        database.stockCounts,
      )..where((row) => row.id.equals(envelope.change.aggregateId))).write(
        StockCountsCompanion(
          completionOperationId: envelope.commandType == 'stock_count.complete'
              ? Value(envelope.change.operationId)
              : const Value.absent(),
          status: Value(_requiredString(countRow, 'status')),
          completedByUserId: envelope.commandType == 'stock_count.complete'
              ? Value(envelope.actorUserId)
              : const Value.absent(),
          completedAt: envelope.commandType == 'stock_count.complete'
              ? Value(
                  _date(countRow['completed_at']) ?? envelope.change.occurredAt,
                )
              : const Value.absent(),
          version: Value(_integer(countRow['version'])),
          updatedAt: Value(envelope.change.occurredAt),
        ),
      );
      final inventory = _map(result['inventory']);
      if (inventory != null) {
        await _applyInventoryTransaction(
          envelope,
          result: inventory,
          payload: {
            'id': result['correctionTransactionId'],
            'transactionType': 'stock_count_correction',
            'referenceType': 'stock_count',
            'referenceId': envelope.change.aggregateId,
            'lines': result['correctionLines'] ?? const <Object?>[],
          },
          operationId: '${envelope.change.operationId}:inventory',
        );
      }
    }
  }

  Future<void> _sale(RemoteChangeEnvelope envelope) async {
    final sale = _requiredMap(envelope.result['sale'], 'sale');
    final payload = envelope.commandPayload;
    final inventory = _requiredMap(envelope.result['inventory'], 'inventory');
    final inventoryPayload = <String, Object?>{
      'id': sale['inventoryTransactionId'],
      'transactionType': 'sale',
      'referenceType': 'sale',
      'referenceId': envelope.change.aggregateId,
      'occurredAt': sale['completedAt'],
      'lines': [
        for (final value in (payload['items'] as List))
          {
            'stockLocationId': _requiredMap(
              value,
              'sale item',
            )['stockLocationId'],
            'productId': _requiredMap(value, 'sale item')['productId'],
            'quantityDeltaMilli': -_integer(
              _requiredMap(value, 'sale item')['quantityMilli'],
            ),
          },
      ],
    };
    final inventoryTransactionId = await _applyInventoryTransaction(
      envelope,
      result: inventory,
      payload: inventoryPayload,
      operationId: '${envelope.change.operationId}:inventory',
    );
    final id = envelope.change.aggregateId;
    final existing = await (database.select(
      database.sales,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    final completedAt =
        _date(sale['completedAt']) ?? envelope.change.occurredAt;
    final registerId = _string(sale['registerId']) ?? existing?.registerId;
    if (registerId == null) {
      throw const FormatException('Sale register is missing.');
    }
    await database
        .into(database.sales)
        .insertOnConflictUpdate(
          SalesCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            branchId: _branchId(envelope),
            registerId: registerId,
            shiftId: Value(_string(sale['shiftId']) ?? existing?.shiftId),
            inventoryTransactionId: Value(
              inventoryTransactionId ?? existing?.inventoryTransactionId,
            ),
            customerId: Value(
              _string(sale['customerId']) ??
                  _string(payload['customerId']) ??
                  existing?.customerId,
            ),
            operationId: existing?.operationId ?? envelope.change.operationId,
            receiptNumber: Value(_string(sale['receiptNumber'])),
            status: Value(_string(sale['status']) ?? 'completed'),
            cashierUserId: envelope.actorUserId,
            subtotalMinor: Value(_integer(payload['subtotalMinor'])),
            discountMinor: Value(_integer(payload['discountMinor'])),
            taxMinor: Value(_integer(payload['taxMinor'])),
            totalMinor: Value(_integer(payload['totalMinor'])),
            tenderedMinor: Value(_integer(payload['tenderedMinor'])),
            changeMinor: Value(_integer(payload['changeMinor'])),
            discountApprovedByUserId: Value(
              _string(payload['discountApprovedByUserId']),
            ),
            completedAt: Value(completedAt),
            version: Value(_nullableInt(sale['version']) ?? 0),
            createdAt: existing?.createdAt ?? envelope.change.occurredAt,
            updatedAt: envelope.change.occurredAt,
          ),
        );
    if (existing != null) return;
    final items = payload['items'] as List;
    for (var index = 0; index < items.length; index++) {
      final item = _requiredMap(items[index], 'sale item');
      final itemId = 'sync:${envelope.change.operationId}:item:$index';
      await database
          .into(database.saleItems)
          .insert(
            SaleItemsCompanion.insert(
              id: itemId,
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              saleId: id,
              productId: _requiredString(item, 'productId'),
              stockLocationId: _requiredString(item, 'stockLocationId'),
              lineNumber: index + 1,
              productNameSnapshot: _string(item['productName']) ?? 'Product',
              skuSnapshot: _string(item['sku']) ?? 'SKU',
              barcodeSnapshot: Value(_string(item['barcode'])),
              unitNameSnapshot: _string(item['unitName']) ?? 'Unit',
              quantityMilli: _integer(item['quantityMilli']),
              unitPriceMinorSnapshot: _integer(item['unitPriceMinor']),
              unitCostMinorSnapshot: _integer(item['unitCostMinor']),
              taxRateBasisPointsSnapshot: _integer(item['taxRateBasisPoints']),
              taxInclusiveSnapshot: item['taxInclusive'] == true,
              grossAmountMinor: _integer(item['grossAmountMinor']),
              discountAmountMinor: _integer(item['discountAmountMinor']),
              netAmountMinor: _integer(item['netAmountMinor']),
              taxAmountMinor: _integer(item['taxAmountMinor']),
              totalAmountMinor: _integer(item['totalAmountMinor']),
              createdAt: envelope.change.occurredAt,
            ),
          );
      final itemDiscount = _nullableInt(item['itemDiscountMinor']) ?? 0;
      if (itemDiscount > 0) {
        await _insertDiscount(
          envelope,
          id,
          itemId,
          itemDiscount,
          _string(item['itemDiscountReason']) ?? 'Item discount',
          index,
        );
      }
    }
    final saleDiscount = items.fold<int>(
      0,
      (total, value) =>
          total +
          (_nullableInt(
                _requiredMap(value, 'sale item')['allocatedSaleDiscountMinor'],
              ) ??
              0),
    );
    if (saleDiscount > 0) {
      await _insertDiscount(
        envelope,
        id,
        null,
        saleDiscount,
        _string(payload['saleDiscountReason']) ?? 'Sale discount',
        items.length,
      );
    }
    final payments = payload['payments'] as List;
    for (var index = 0; index < payments.length; index++) {
      final payment = _requiredMap(payments[index], 'payment');
      await database
          .into(database.payments)
          .insert(
            PaymentsCompanion.insert(
              id: 'sync:${envelope.change.operationId}:payment:$index',
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              saleId: id,
              shiftId: Value(_string(sale['shiftId'])),
              paymentMethod: _requiredString(payment, 'method'),
              tenderedAmountMinor: _integer(payment['tenderedAmountMinor']),
              appliedAmountMinor: _integer(payment['appliedAmountMinor']),
              changeAmountMinor: Value(_integer(payment['changeAmountMinor'])),
              reference: Value(_string(payment['reference'])),
              createdAt: envelope.change.occurredAt,
            ),
          );
    }
  }

  Future<void> _saleCorrection(RemoteChangeEnvelope envelope) async {
    final result = envelope.result;
    final payload = envelope.commandPayload;
    final correction = _requiredMap(result['correction'], 'correction');
    final correctionId = envelope.change.aggregateId;
    final saleId = _requiredString(correction, 'saleId');
    final sale = await (database.select(
      database.sales,
    )..where((row) => row.id.equals(saleId))).getSingleOrNull();
    if (sale == null) {
      throw const FormatException(
        'Original sale must synchronize before its correction.',
      );
    }

    final inventory = _map(result['inventory']);
    if (inventory != null) {
      final correctionItems = payload['items'];
      await _applyInventoryTransaction(
        envelope,
        result: inventory,
        payload: {
          'id': correction['inventoryTransactionId'],
          'transactionType': 'sale_return',
          'reasonCode': correction['reasonCode'],
          'notes': correction['notes'],
          'referenceType': 'sale_correction',
          'referenceId': correctionId,
          'approvedByUserId': correction['approvedByUserId'],
          'occurredAt': correction['completedAt'],
          'lines': [
            if (correctionItems is List)
              for (final value in correctionItems)
                if (_requiredMap(value, 'correction item')['disposition'] !=
                    'non_restock')
                  {
                    'stockLocationId': _requiredMap(
                      value,
                      'correction item',
                    )['destinationStockLocationId'],
                    'productId': _requiredMap(
                      value,
                      'correction item',
                    )['productId'],
                    'quantityDeltaMilli': _requiredMap(
                      value,
                      'correction item',
                    )['quantityMilli'],
                  },
          ],
        },
        operationId: '${envelope.change.operationId}:inventory',
      );
    }

    final existing = await (database.select(
      database.saleReturns,
    )..where((row) => row.id.equals(correctionId))).getSingleOrNull();
    if (existing != null) {
      if (existing.status != 'completed') {
        await (database.update(
          database.saleReturns,
        )..where((row) => row.id.equals(correctionId))).write(
          SaleReturnsCompanion(
            status: const Value('completed'),
            updatedAt: Value(envelope.change.occurredAt),
          ),
        );
      }
      return;
    }

    final completedAt =
        _date(correction['completedAt']) ?? envelope.change.occurredAt;
    final approvalRequestId = _string(correction['approvalRequestId']);
    final approvedByUserId = _string(correction['approvedByUserId']);
    if (approvalRequestId != null) {
      await database
          .into(database.approvalRequests)
          .insert(
            ApprovalRequestsCompanion.insert(
              id: approvalRequestId,
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              operationId: '${envelope.change.operationId}:approval',
              requestType: envelope.commandType == 'sale.void'
                  ? 'sale_void'
                  : 'sale_return',
              entityType: 'sale',
              entityId: saleId,
              status: const Value('approved'),
              requestedByUserId: envelope.actorUserId,
              reason: _requiredString(correction, 'reasonCode'),
              actualAmountMinor: _integer(correction['totalMinor']),
              requestedAt: completedAt,
              resolvedAt: Value(completedAt),
              createdAt: envelope.change.occurredAt,
              updatedAt: envelope.change.occurredAt,
            ),
          );
      await database
          .into(database.approvalDecisions)
          .insert(
            ApprovalDecisionsCompanion.insert(
              id: 'sync:${envelope.change.operationId}:decision',
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              approvalRequestId: approvalRequestId,
              decision: 'approved',
              decidedByUserId: approvedByUserId ?? envelope.actorUserId,
              notes: Value(_string(correction['notes'])),
              decidedAt: completedAt,
              createdAt: envelope.change.occurredAt,
            ),
          );
    }

    final cash = _map(result['cashMovement']);
    if (cash != null) {
      await database
          .into(database.cashMovements)
          .insert(
            CashMovementsCompanion.insert(
              id: _requiredString(cash, 'id'),
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              registerId: _requiredString(cash, 'registerId'),
              shiftId: _requiredString(cash, 'shiftId'),
              operationId: '${envelope.change.operationId}:cash_refund',
              movementType: 'cash_out',
              amountMinor: -_refundAmount(result, 'cash'),
              reason:
                  'Refund ${_requiredString(correction, 'returnNumber')}: '
                  '${_requiredString(correction, 'reasonCode')}',
              createdByUserId: envelope.actorUserId,
              approvedByUserId: Value(approvedByUserId),
              approvedAt: Value(approvedByUserId == null ? null : completedAt),
              occurredAt: completedAt,
              createdAt: envelope.change.occurredAt,
            ),
          );
    }

    await database
        .into(database.saleReturns)
        .insert(
          SaleReturnsCompanion.insert(
            id: correctionId,
            organizationId: envelope.change.organizationId,
            branchId: _branchId(envelope),
            saleId: saleId,
            operationId: envelope.change.operationId,
            returnNumber: _requiredString(correction, 'returnNumber'),
            correctionType: _requiredString(correction, 'correctionType'),
            reasonCode: _requiredString(correction, 'reasonCode'),
            notes: Value(_string(correction['notes'])),
            inventoryTransactionId: Value(
              _string(correction['inventoryTransactionId']),
            ),
            approvalRequestId: Value(approvalRequestId),
            subtotalMinor: _integer(correction['subtotalMinor']),
            discountMinor: _integer(correction['discountMinor']),
            taxMinor: _integer(correction['taxMinor']),
            totalMinor: _integer(correction['totalMinor']),
            createdByUserId: envelope.actorUserId,
            approvedByUserId: Value(approvedByUserId),
            approvedAt: Value(approvedByUserId == null ? null : completedAt),
            completedAt: completedAt,
            createdAt: envelope.change.occurredAt,
            updatedAt: envelope.change.occurredAt,
          ),
        );

    final localItems = await (database.select(
      database.saleItems,
    )..where((row) => row.saleId.equals(saleId))).get();
    final localByLine = {for (final item in localItems) item.lineNumber: item};
    final items = result['items'];
    if (items is! List) {
      throw const FormatException('Correction items are missing.');
    }
    for (var index = 0; index < items.length; index++) {
      final item = _requiredMap(items[index], 'correction item');
      final saleItem = localByLine[_integer(item['lineNumber'])];
      if (saleItem == null) {
        throw const FormatException('Correction sale item is unavailable.');
      }
      await database
          .into(database.saleReturnItems)
          .insert(
            SaleReturnItemsCompanion.insert(
              id:
                  _string(item['id']) ??
                  'sync:${envelope.change.operationId}:item:$index',
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              saleReturnId: correctionId,
              saleItemId: saleItem.id,
              productId: saleItem.productId,
              disposition: _requiredString(item, 'disposition'),
              destinationStockLocationId: Value(
                _string(item['destinationStockLocationId']),
              ),
              quantityMilli: _integer(item['quantityMilli']),
              subtotalMinor: _integer(item['subtotalMinor']),
              discountMinor: _integer(item['discountMinor']),
              taxMinor: _integer(item['taxMinor']),
              totalMinor: _integer(item['totalMinor']),
              createdAt: envelope.change.occurredAt,
            ),
          );
    }

    final refunds = result['refunds'];
    if (refunds is! List) {
      throw const FormatException('Correction refunds are missing.');
    }
    for (var index = 0; index < refunds.length; index++) {
      final refund = _requiredMap(refunds[index], 'refund');
      await database
          .into(database.refundPayments)
          .insert(
            RefundPaymentsCompanion.insert(
              id:
                  _string(refund['id']) ??
                  'sync:${envelope.change.operationId}:refund:$index',
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              saleReturnId: correctionId,
              shiftId: Value(_string(refund['shiftId'])),
              cashMovementId: Value(_string(refund['cashMovementId'])),
              refundMethod: _requiredString(refund, 'method'),
              amountMinor: _integer(refund['amountMinor']),
              reference: Value(_string(refund['reference'])),
              createdAt: envelope.change.occurredAt,
            ),
          );
    }
  }

  Future<void> _customer(RemoteChangeEnvelope envelope) async {
    final target = _map(envelope.result['target']);
    if (target != null) {
      await _applyCustomerResult(envelope, target);
    }
    await _applyCustomerResult(envelope, envelope.result);
    if (envelope.commandType == 'customer.merge') {
      final sourceId = envelope.change.aggregateId;
      final targetId = _requiredString(
        envelope.commandPayload,
        'targetCustomerId',
      );
      await (database.update(database.sales)..where(
            (row) =>
                row.organizationId.equals(envelope.change.organizationId) &
                row.customerId.equals(sourceId),
          ))
          .write(
            SalesCompanion(
              customerId: Value(targetId),
              updatedAt: Value(envelope.change.occurredAt),
            ),
          );
      await (database.update(database.customerNotes)..where(
            (row) =>
                row.organizationId.equals(envelope.change.organizationId) &
                row.customerId.equals(sourceId),
          ))
          .write(
            CustomerNotesCompanion(
              customerId: Value(targetId),
              updatedAt: Value(envelope.change.occurredAt),
            ),
          );
    }
    if (envelope.commandType == 'customer.anonymize') {
      await (database.update(database.customerNotes)..where(
            (row) =>
                row.organizationId.equals(envelope.change.organizationId) &
                row.customerId.equals(envelope.change.aggregateId),
          ))
          .write(
            CustomerNotesCompanion(
              body: const Value('[anonymized]'),
              deletedAt: Value(envelope.change.occurredAt),
              updatedAt: Value(envelope.change.occurredAt),
            ),
          );
    }
  }

  Future<void> _applyCustomerResult(
    RemoteChangeEnvelope envelope,
    Map<String, Object?> result,
  ) async {
    final customer = _requiredMap(result['customer'], 'customer');
    final id = _requiredString(customer, 'id');
    final existing =
        await (database.select(database.customers)..where(
              (row) =>
                  row.id.equals(id) &
                  row.organizationId.equals(envelope.change.organizationId),
            ))
            .getSingleOrNull();
    final occurredAt = envelope.change.occurredAt;
    final status = _requiredString(customer, 'status');
    await database
        .into(database.customers)
        .insertOnConflictUpdate(
          CustomersCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            customerNumber: _requiredString(customer, 'customerNumber'),
            displayName: _requiredString(customer, 'displayName'),
            normalizedName: _normalizeSyncSearch(
              _requiredString(customer, 'displayName'),
            ),
            email: Value(_string(customer['email'])),
            normalizedEmail: Value(_string(customer['normalizedEmail'])),
            phone: Value(_string(customer['phone'])),
            normalizedPhone: Value(_string(customer['normalizedPhone'])),
            birthDate: Value(_date(customer['birthDate'])),
            marketingConsent: Value(customer['marketingConsent'] == true),
            status: Value(status),
            mergedIntoCustomerId: Value(
              _string(customer['mergedIntoCustomerId']),
            ),
            archivedAt: Value(_date(customer['archivedAt'])),
            anonymizedAt: Value(_date(customer['anonymizedAt'])),
            version: Value(_integer(customer['version'])),
            createdAt:
                _date(customer['createdAt']) ??
                existing?.createdAt ??
                occurredAt,
            updatedAt: _date(customer['updatedAt']) ?? occurredAt,
          ),
        );

    final addresses = result['addresses'];
    if (addresses is List) {
      for (final value in addresses) {
        final address = _requiredMap(value, 'customer address');
        final addressId = _requiredString(address, 'id');
        final local = await (database.select(
          database.customerAddresses,
        )..where((row) => row.id.equals(addressId))).getSingleOrNull();
        await database
            .into(database.customerAddresses)
            .insertOnConflictUpdate(
              CustomerAddressesCompanion.insert(
                id: addressId,
                organizationId: envelope.change.organizationId,
                customerId: id,
                label: _requiredString(address, 'label'),
                recipientName: Value(_string(address['recipientName'])),
                lineOne: _requiredString(address, 'lineOne'),
                lineTwo: Value(_string(address['lineTwo'])),
                city: _requiredString(address, 'city'),
                province: Value(_string(address['province'])),
                postalCode: Value(_string(address['postalCode'])),
                countryCode: Value(_requiredString(address, 'countryCode')),
                isPrimary: Value(address['isPrimary'] == true),
                version: Value(_nullableInt(address['version']) ?? 0),
                createdAt:
                    _date(address['createdAt']) ??
                    local?.createdAt ??
                    occurredAt,
                updatedAt: _date(address['updatedAt']) ?? occurredAt,
                deletedAt: Value(_date(address['deletedAt'])),
              ),
            );
      }
    }

    final notes = result['notes'];
    if (notes is List) {
      for (final value in notes) {
        final note = _requiredMap(value, 'customer note');
        final noteId = _requiredString(note, 'id');
        final local = await (database.select(
          database.customerNotes,
        )..where((row) => row.id.equals(noteId))).getSingleOrNull();
        await database
            .into(database.customerNotes)
            .insertOnConflictUpdate(
              CustomerNotesCompanion.insert(
                id: noteId,
                organizationId: envelope.change.organizationId,
                branchId: _requiredString(note, 'branchId'),
                customerId: id,
                body: _requiredString(note, 'body'),
                createdByUserId: _requiredString(note, 'createdByUserId'),
                createdAt:
                    _date(note['createdAt']) ?? local?.createdAt ?? occurredAt,
                updatedAt: _date(note['updatedAt']) ?? occurredAt,
                deletedAt: Value(_date(note['deletedAt'])),
              ),
            );
      }
    }

    final account = _map(result['loyaltyAccount']);
    if (account == null) return;
    final accountId = _requiredString(account, 'id');
    final localAccount = await (database.select(
      database.loyaltyAccounts,
    )..where((row) => row.id.equals(accountId))).getSingleOrNull();
    await database
        .into(database.loyaltyAccounts)
        .insertOnConflictUpdate(
          LoyaltyAccountsCompanion.insert(
            id: accountId,
            organizationId: envelope.change.organizationId,
            customerId: id,
            status: Value(_requiredString(account, 'status')),
            pointsBalance: Value(_integer(account['pointsBalance'])),
            lifetimeEarnedPoints: Value(
              _integer(account['lifetimeEarnedPoints']),
            ),
            lifetimeRedeemedPoints: Value(
              _integer(account['lifetimeRedeemedPoints']),
            ),
            version: Value(_integer(account['version'])),
            createdAt:
                _date(account['createdAt']) ??
                localAccount?.createdAt ??
                occurredAt,
            updatedAt: _date(account['updatedAt']) ?? occurredAt,
            closedAt: Value(_date(account['closedAt'])),
          ),
        );
    final entries = result['loyaltyEntries'];
    if (entries is! List) return;
    for (final value in entries) {
      final entry = _requiredMap(value, 'loyalty ledger entry');
      await database
          .into(database.loyaltyLedgerEntries)
          .insert(
            LoyaltyLedgerEntriesCompanion.insert(
              id: _requiredString(entry, 'id'),
              organizationId: envelope.change.organizationId,
              branchId: Value(_string(entry['branchId'])),
              accountId: accountId,
              saleId: Value(_string(entry['saleId'])),
              operationId: _requiredString(entry, 'operationId'),
              entryType: _requiredString(entry, 'entryType'),
              pointsDelta: _integer(entry['pointsDelta']),
              balanceAfter: _integer(entry['balanceAfter']),
              reason: _requiredString(entry, 'reason'),
              referenceType: Value(_string(entry['referenceType'])),
              referenceId: Value(_string(entry['referenceId'])),
              createdByUserId: _requiredString(entry, 'createdByUserId'),
              occurredAt: _date(entry['occurredAt']) ?? occurredAt,
              createdAt: _date(entry['createdAt']) ?? occurredAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> _supplier(RemoteChangeEnvelope envelope) async {
    final supplier = _requiredMap(envelope.result['supplier'], 'supplier');
    final id = _requiredString(supplier, 'id');
    final existing =
        await (database.select(database.suppliers)..where(
              (row) =>
                  row.id.equals(id) &
                  row.organizationId.equals(envelope.change.organizationId),
            ))
            .getSingleOrNull();
    final occurredAt = envelope.change.occurredAt;
    final deletedAt = _date(supplier['deletedAt']);
    final code = _requiredString(supplier, 'code');
    final name = _requiredString(supplier, 'name');
    await database
        .into(database.suppliers)
        .insertOnConflictUpdate(
          SuppliersCompanion.insert(
            id: id,
            organizationId: envelope.change.organizationId,
            code: code,
            normalizedCode: _normalizeSyncSearch(code),
            name: name,
            normalizedName: _normalizeSyncSearch(name),
            taxIdentifier: Value(_string(supplier['taxIdentifier'])),
            paymentTermsDays: Value(_integer(supplier['paymentTermsDays'])),
            isActive: Value(supplier['isActive'] == true),
            version: Value(_integer(supplier['version'])),
            createdAt:
                _date(supplier['createdAt']) ??
                existing?.createdAt ??
                occurredAt,
            updatedAt: _date(supplier['updatedAt']) ?? occurredAt,
            deletedAt: Value(deletedAt),
          ),
        );
    final contacts = envelope.result['contacts'];
    if (contacts is! List) return;
    for (final value in contacts) {
      final contact = _requiredMap(value, 'supplier contact');
      final contactId = _requiredString(contact, 'id');
      final local = await (database.select(
        database.supplierContacts,
      )..where((row) => row.id.equals(contactId))).getSingleOrNull();
      await database
          .into(database.supplierContacts)
          .insertOnConflictUpdate(
            SupplierContactsCompanion.insert(
              id: contactId,
              organizationId: envelope.change.organizationId,
              supplierId: id,
              name: _requiredString(contact, 'name'),
              role: Value(_string(contact['role'])),
              email: Value(_string(contact['email'])),
              phone: Value(_string(contact['phone'])),
              isPrimary: Value(contact['isPrimary'] == true),
              createdAt: local?.createdAt ?? occurredAt,
              updatedAt: occurredAt,
            ),
          );
    }
  }

  Future<void> _purchaseOrder(RemoteChangeEnvelope envelope) async {
    final order = _requiredMap(
      envelope.result['purchaseOrder'],
      'purchase order',
    );
    final orderId = _requiredString(order, 'id');
    final existing =
        await (database.select(database.purchaseOrders)..where(
              (row) =>
                  row.id.equals(orderId) &
                  row.organizationId.equals(envelope.change.organizationId),
            ))
            .getSingleOrNull();
    final occurredAt = envelope.change.occurredAt;
    await database
        .into(database.purchaseOrders)
        .insertOnConflictUpdate(
          PurchaseOrdersCompanion.insert(
            id: orderId,
            organizationId: envelope.change.organizationId,
            branchId: _branchId(envelope),
            supplierId: _requiredString(order, 'supplierId'),
            orderNumber: _requiredString(order, 'orderNumber'),
            status: _requiredString(order, 'status'),
            notes: Value(_string(order['notes'])),
            expectedDeliveryAt: Value(_date(order['expectedDeliveryAt'])),
            createdByUserId:
                _string(order['createdByUserId']) ?? envelope.actorUserId,
            approvedByUserId: Value(_string(order['approvedByUserId'])),
            cancellationReason: Value(_string(order['cancellationReason'])),
            submittedAt: Value(_date(order['submittedAt'])),
            approvedAt: Value(_date(order['approvedAt'])),
            cancelledAt: Value(_date(order['cancelledAt'])),
            version: Value(_integer(order['version'])),
            createdAt:
                _date(order['createdAt']) ?? existing?.createdAt ?? occurredAt,
            updatedAt: _date(order['updatedAt']) ?? occurredAt,
          ),
        );

    final itemValues = envelope.result['items'];
    if (itemValues is! List) {
      throw const FormatException('Purchase order items are missing.');
    }
    for (final value in itemValues) {
      final item = _requiredMap(value, 'purchase order item');
      final itemId = _requiredString(item, 'id');
      final local = await (database.select(
        database.purchaseOrderItems,
      )..where((row) => row.id.equals(itemId))).getSingleOrNull();
      await database
          .into(database.purchaseOrderItems)
          .insertOnConflictUpdate(
            PurchaseOrderItemsCompanion.insert(
              id: itemId,
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              purchaseOrderId: orderId,
              productId: _requiredString(item, 'productId'),
              orderedQuantityMilli: _integer(item['orderedQuantityMilli']),
              receivedQuantityMilli: Value(
                _integer(item['receivedQuantityMilli']),
              ),
              cancelledQuantityMilli: Value(
                _integer(item['cancelledQuantityMilli']),
              ),
              unitCostMinor: Value(_integer(item['unitCostMinor'])),
              estimatedLandedCostMinor: Value(
                _integer(item['estimatedLandedCostMinor']),
              ),
              version: Value(_integer(item['version'])),
              createdAt: local?.createdAt ?? occurredAt,
              updatedAt: occurredAt,
            ),
          );
    }

    final receipts = envelope.result['receipts'];
    if (receipts is List) {
      for (final value in receipts) {
        final receipt = _requiredMap(value, 'goods receipt');
        final receiptId = _requiredString(receipt, 'id');
        final local = await (database.select(
          database.goodsReceipts,
        )..where((row) => row.id.equals(receiptId))).getSingleOrNull();
        await database
            .into(database.goodsReceipts)
            .insertOnConflictUpdate(
              GoodsReceiptsCompanion.insert(
                id: receiptId,
                organizationId: envelope.change.organizationId,
                branchId: _branchId(envelope),
                purchaseOrderId: orderId,
                supplierId: _requiredString(order, 'supplierId'),
                stockLocationId: _requiredString(receipt, 'stockLocationId'),
                receiptNumber: _requiredString(receipt, 'receiptNumber'),
                operationId:
                    _string(receipt['operationId']) ??
                    local?.operationId ??
                    envelope.change.operationId,
                supplierDocumentNumber: Value(
                  _string(receipt['supplierDocumentNumber']),
                ),
                notes: Value(_string(receipt['notes'])),
                receivedByUserId:
                    _string(receipt['receivedByUserId']) ??
                    envelope.actorUserId,
                receivedAt: _date(receipt['receivedAt']) ?? occurredAt,
                createdAt: local?.createdAt ?? occurredAt,
              ),
            );
      }
    }

    final inventory = _map(envelope.result['inventory']);
    if (inventory != null) {
      final inventoryLines = inventory['lines'];
      if (inventoryLines is List && await _hasLocalLocations(inventoryLines)) {
        await _applyInventoryTransaction(
          envelope,
          result: inventory,
          payload: {
            'transactionType': 'purchase_receipt',
            'reasonCode': 'purchase_receipt',
            'referenceType': 'goods_receipt',
            'referenceId': _string(envelope.commandPayload['receiptId']),
            'occurredAt': _string(envelope.commandPayload['receivedAt']),
            'lines': inventoryLines,
          },
          operationId: '${envelope.change.operationId}:inventory',
        );
      }
    }

    final receiptItems = envelope.result['receiptItems'];
    if (receiptItems is! List) return;
    for (final value in receiptItems) {
      final item = _requiredMap(value, 'goods receipt item');
      await database
          .into(database.goodsReceiptItems)
          .insert(
            GoodsReceiptItemsCompanion.insert(
              id: _requiredString(item, 'id'),
              organizationId: envelope.change.organizationId,
              branchId: _branchId(envelope),
              goodsReceiptId: _requiredString(item, 'goodsReceiptId'),
              purchaseOrderItemId: _requiredString(item, 'purchaseOrderItemId'),
              productId: _requiredString(item, 'productId'),
              inventoryTransactionId: _requiredString(
                item,
                'inventoryTransactionId',
              ),
              receivedQuantityMilli: _integer(item['receivedQuantityMilli']),
              unitCostMinor: _integer(item['unitCostMinor']),
              freightCostMinor: Value(_integer(item['freightCostMinor'])),
              dutyCostMinor: Value(_integer(item['dutyCostMinor'])),
              otherLandedCostMinor: Value(
                _integer(item['otherLandedCostMinor']),
              ),
              landedUnitCostMinor: _integer(item['landedUnitCostMinor']),
              weightedAverageCostMinorAfter: _integer(
                item['weightedAverageCostMinorAfter'],
              ),
              createdAt: occurredAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> _transfer(RemoteChangeEnvelope envelope) async {
    final transfer = _requiredMap(envelope.result['transfer'], 'transfer');
    final transferId = _requiredString(transfer, 'id');
    final sourceBranchId = _requiredString(transfer, 'sourceBranchId');
    final destinationBranchId = _requiredString(
      transfer,
      'destinationBranchId',
    );
    final existing =
        await (database.select(database.stockTransfers)..where(
              (row) =>
                  row.id.equals(transferId) &
                  row.organizationId.equals(envelope.change.organizationId),
            ))
            .getSingleOrNull();
    final occurredAt = envelope.change.occurredAt;
    await database
        .into(database.stockTransfers)
        .insertOnConflictUpdate(
          StockTransfersCompanion.insert(
            id: transferId,
            organizationId: envelope.change.organizationId,
            sourceBranchId: sourceBranchId,
            destinationBranchId: destinationBranchId,
            transferNumber: _requiredString(transfer, 'transferNumber'),
            status: _requiredString(transfer, 'status'),
            approvalRequired: Value(transfer['approvalRequired'] == true),
            notes: Value(_string(transfer['notes'])),
            createdByUserId:
                _string(transfer['createdByUserId']) ?? envelope.actorUserId,
            approvedByUserId: Value(_string(transfer['approvedByUserId'])),
            rejectionReason: Value(_string(transfer['rejectionReason'])),
            cancellationReason: Value(_string(transfer['cancellationReason'])),
            submittedAt: Value(_date(transfer['submittedAt'])),
            approvedAt: Value(_date(transfer['approvedAt'])),
            shippedAt: Value(_date(transfer['shippedAt'])),
            receivedAt: Value(_date(transfer['receivedAt'])),
            cancelledAt: Value(_date(transfer['cancelledAt'])),
            version: Value(_integer(transfer['version'])),
            createdAt:
                _date(transfer['createdAt']) ??
                existing?.createdAt ??
                occurredAt,
            updatedAt: _date(transfer['updatedAt']) ?? occurredAt,
          ),
        );

    final itemValues = envelope.result['items'];
    if (itemValues is! List) {
      throw const FormatException('Transfer items are missing.');
    }
    for (final value in itemValues) {
      final item = _requiredMap(value, 'transfer item');
      final itemId = _requiredString(item, 'id');
      final local = await (database.select(
        database.stockTransferItems,
      )..where((row) => row.id.equals(itemId))).getSingleOrNull();
      await database
          .into(database.stockTransferItems)
          .insertOnConflictUpdate(
            StockTransferItemsCompanion.insert(
              id: itemId,
              organizationId: envelope.change.organizationId,
              transferId: transferId,
              productId: _requiredString(item, 'productId'),
              sourceStockLocationId: _requiredString(
                item,
                'sourceStockLocationId',
              ),
              destinationStockLocationId: _requiredString(
                item,
                'destinationStockLocationId',
              ),
              damagedStockLocationId: Value(
                _string(item['damagedStockLocationId']),
              ),
              requestedQuantityMilli: _integer(item['requestedQuantityMilli']),
              shippedQuantityMilli: Value(
                _integer(item['shippedQuantityMilli']),
              ),
              receivedQuantityMilli: Value(
                _integer(item['receivedQuantityMilli']),
              ),
              damagedQuantityMilli: Value(
                _integer(item['damagedQuantityMilli']),
              ),
              discrepancyQuantityMilli: Value(
                _integer(item['discrepancyQuantityMilli']),
              ),
              version: Value(_integer(item['version'])),
              createdAt: local?.createdAt ?? occurredAt,
              updatedAt: occurredAt,
            ),
          );
    }

    final event = _requiredMap(envelope.result['event'], 'transfer event');
    final priorEvent =
        await (database.select(database.transferEvents)..where(
              (row) => row.operationId.equals(envelope.change.operationId),
            ))
            .getSingleOrNull();
    if (priorEvent == null) {
      await database
          .into(database.transferEvents)
          .insert(
            TransferEventsCompanion.insert(
              id: _requiredString(event, 'id'),
              organizationId: envelope.change.organizationId,
              transferId: transferId,
              operationId: envelope.change.operationId,
              eventType: _requiredString(event, 'eventType'),
              fromStatus: Value(_string(event['fromStatus'])),
              toStatus: _requiredString(event, 'toStatus'),
              actorUserId:
                  _string(event['actorUserId']) ?? envelope.actorUserId,
              reason: Value(_string(event['reason'])),
              metadataJson: Value(
                jsonEncode(
                  _map(event['metadata']) ?? const <String, Object?>{},
                ),
              ),
              occurredAt: _date(event['occurredAt']) ?? occurredAt,
              createdAt: occurredAt,
            ),
          );
    }

    await _applyTransferBalances(
      envelope,
      envelope.result['balances'],
      sourceBranchId,
    );
    await _applyTransferBalances(
      envelope,
      envelope.result['reservationBalances'],
      sourceBranchId,
    );
    final inventory = _map(envelope.result['inventory']);
    if (inventory != null) {
      final transaction = _map(inventory['inventoryTransaction']);
      final lines = inventory['lines'];
      if (transaction != null && lines is List) {
        final branchId = envelope.commandType == 'transfer.ship'
            ? sourceBranchId
            : destinationBranchId;
        final canApply = await _hasLocalLocations(lines);
        if (canApply) {
          final scoped = _withBranch(envelope, branchId);
          await _applyInventoryTransaction(
            scoped,
            result: inventory,
            payload: {
              'transactionType': _requiredString(
                transaction,
                'transactionType',
              ),
              'occurredAt': _string(transaction['occurredAt']),
              'referenceType':
                  envelope.commandType == 'transfer.correct_receipt'
                  ? 'stock_transfer_correction'
                  : 'stock_transfer',
              'referenceId': transferId,
              'lines': lines,
            },
            operationId: '${envelope.change.operationId}:inventory',
          );
        }
      }
    }
  }

  Future<void> _applyTransferBalances(
    RemoteChangeEnvelope envelope,
    Object? values,
    String branchId,
  ) async {
    if (values is! List) return;
    final scoped = _withBranch(envelope, branchId);
    for (final value in values) {
      final balance = _requiredMap(value, 'transfer balance');
      final locationId = _requiredString(balance, 'stockLocationId');
      final available = await (database.select(
        database.stockLocations,
      )..where((row) => row.id.equals(locationId))).getSingleOrNull();
      if (available == null) continue;
      await _applyBalance(
        scoped,
        balance,
        stockLocationId: locationId,
        productId: _requiredString(balance, 'productId'),
      );
    }
  }

  Future<bool> _hasLocalLocations(List<Object?> lines) async {
    for (final value in lines) {
      final line = _requiredMap(value, 'inventory line');
      final location =
          await (database.select(database.stockLocations)..where(
                (row) =>
                    row.id.equals(_requiredString(line, 'stockLocationId')),
              ))
              .getSingleOrNull();
      if (location == null) return false;
    }
    return true;
  }

  RemoteChangeEnvelope _withBranch(
    RemoteChangeEnvelope envelope,
    String branchId,
  ) => RemoteChangeEnvelope(
    change: RemoteChange(
      sequence: envelope.change.sequence,
      organizationId: envelope.change.organizationId,
      branchId: branchId,
      aggregateType: envelope.change.aggregateType,
      aggregateId: envelope.change.aggregateId,
      operationId: envelope.change.operationId,
      changeType: envelope.change.changeType,
      version: envelope.change.version,
      payload: envelope.change.payload,
      occurredAt: envelope.change.occurredAt,
    ),
    commandType: envelope.commandType,
    actorUserId: envelope.actorUserId,
    commandPayload: envelope.commandPayload,
    result: envelope.result,
  );

  Future<void> _insertDiscount(
    RemoteChangeEnvelope envelope,
    String saleId,
    String? itemId,
    int amount,
    String reason,
    int index,
  ) {
    return database
        .into(database.saleDiscounts)
        .insert(
          SaleDiscountsCompanion.insert(
            id: 'sync:${envelope.change.operationId}:discount:$index',
            organizationId: envelope.change.organizationId,
            branchId: _branchId(envelope),
            saleId: saleId,
            saleItemId: Value(itemId),
            discountScope: itemId == null ? 'sale' : 'item',
            amountMinor: amount,
            reason: reason,
            approvedByUserId: Value(
              _string(envelope.commandPayload['discountApprovedByUserId']),
            ),
            createdAt: envelope.change.occurredAt,
          ),
        );
  }

  String _branchId(RemoteChangeEnvelope envelope) {
    return envelope.change.branchId ??
        (throw const FormatException(
          'Branch-scoped remote change is missing its branch.',
        ));
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
  final result = _string(value[key])?.trim();
  if (result == null || result.isEmpty) {
    throw FormatException('$key is required.');
  }
  return result;
}

int _integer(Object? value) => value is int
    ? value
    : int.parse(
        value?.toString() ?? (throw const FormatException('Integer required.')),
      );

int? _nullableInt(Object? value) => value == null ? null : _integer(value);

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value.toString()).toUtc();

String _normalizeSyncSearch(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

int _refundAmount(Map<String, Object?> result, String method) {
  final refunds = result['refunds'];
  if (refunds is! List) {
    throw const FormatException('Correction refunds are missing.');
  }
  for (final value in refunds) {
    final refund = _requiredMap(value, 'refund');
    if (_string(refund['method']) == method) {
      return _integer(refund['amountMinor']);
    }
  }
  throw FormatException('$method refund is missing.');
}
