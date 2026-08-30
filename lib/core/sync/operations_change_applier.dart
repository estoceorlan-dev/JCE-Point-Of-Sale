import 'package:drift/drift.dart';

import '../database/app_database.dart';
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
    } else if (type == 'device.register') {
      // Device registration has no local business projection.
    } else {
      return false;
    }
    return true;
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
            reservedMilli: Value(existing?.reservedMilli ?? 0),
            reorderPointMilli: Value(
              _nullableInt(
                    value['reorder_point_milli'] ?? value['reorderPointMilli'],
                  ) ??
                  existing?.reorderPointMilli ??
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
