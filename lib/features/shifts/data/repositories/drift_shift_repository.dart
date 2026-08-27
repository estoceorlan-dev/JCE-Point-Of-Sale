import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart'
    hide CashMovement, Register, ShiftCount;
import '../../../../core/database/app_database.dart'
    as db
    show Branche, CashMovement, Register;
import '../../../../core/database/local_mutation_transaction.dart';
import '../../../../core/database/models/outbox_command.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/audit_log_entry.dart';
import '../../../../shared/models/business_context.dart';
import '../../domain/entities/cash_movement.dart';
import '../../domain/entities/cash_shift.dart';
import '../../domain/entities/register.dart';
import '../../domain/repositories/shift_repository.dart';
import '../data_sources/shift_local_data_source.dart';

class DriftShiftRepository implements ShiftRepository {
  const DriftShiftRepository({
    required AppDatabase database,
    required ShiftLocalDataSource localDataSource,
    required LocalMutationTransaction localMutationTransaction,
    required IdGenerator idGenerator,
    required AppClock clock,
  }) : _database = database,
       _localDataSource = localDataSource,
       _localMutationTransaction = localMutationTransaction,
       _idGenerator = idGenerator,
       _clock = clock;

  final AppDatabase _database;
  final ShiftLocalDataSource _localDataSource;
  final LocalMutationTransaction _localMutationTransaction;
  final IdGenerator _idGenerator;
  final AppClock _clock;

  @override
  Stream<List<Register>> watchRegisters({required BusinessContext context}) {
    return _localDataSource.watchRegisters(
      organizationId: context.organizationId,
      branchId: context.branchId,
    );
  }

  @override
  Stream<CashShift?> watchActiveShift({
    required BusinessContext context,
    required String deviceId,
  }) {
    return _localDataSource.watchActiveShift(
      organizationId: context.organizationId,
      branchId: context.branchId,
      deviceId: deviceId,
    );
  }

  @override
  Stream<List<CashShift>> watchRecentShifts({
    required BusinessContext context,
  }) {
    return _localDataSource.watchRecentShifts(
      organizationId: context.organizationId,
      branchId: context.branchId,
    );
  }

  @override
  Future<CashShift?> getShift({
    required BusinessContext context,
    required String shiftId,
  }) {
    return _localDataSource.getShift(
      organizationId: context.organizationId,
      branchId: context.branchId,
      shiftId: shiftId,
    );
  }

  @override
  Future<Result<String, Failure>> createRegister({
    required BusinessContext context,
    required RegisterDraft draft,
  }) async {
    final code = _normalizeCode(draft.code);
    final name = draft.name.trim();
    if (code.length < 2 || code.length > 20 || name.length < 2) {
      return const Result.failure(
        ValidationFailure(
          'Register code must be 2–20 characters and the name is required.',
        ),
      );
    }
    final duplicate =
        await (_database.select(_database.registers)..where(
              (row) =>
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.code.equals(code),
            ))
            .getSingleOrNull();
    if (duplicate != null) {
      return const Result.failure(
        ConflictFailure('A register with this code already exists.'),
      );
    }
    final id = _idGenerator.newId();
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        await database
            .into(database.registers)
            .insert(
              RegistersCompanion.insert(
                id: id,
                organizationId: context.organizationId,
                branchId: context.branchId,
                code: code,
                name: name,
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
        entityName: 'register',
        entityId: id,
        metadata: {'code': code, 'name': name},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'register.create',
        aggregateType: 'register',
        aggregateId: id,
        payload: {'id': id, 'code': code, 'name': name},
        now: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> assignDevice({
    required BusinessContext context,
    required String registerId,
    required String deviceId,
    required int expectedVersion,
  }) async {
    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty) {
      return const Result.failure(
        ValidationFailure('A device ID is required.'),
      );
    }
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final register = await _requireRegister(database, context, registerId);
        if (register.version != expectedVersion) {
          throw const ConflictFailure(
            'The register changed. Refresh before assigning this device.',
          );
        }
        final activeShift =
            await (database.select(database.shifts)..where(
                  (row) =>
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.deviceId.equals(normalizedDeviceId) &
                      row.status.equals('open'),
                ))
                .getSingleOrNull();
        if (activeShift != null && activeShift.registerId != registerId) {
          throw const ConflictFailure(
            'This device has an open shift on another register.',
          );
        }
        final priorAssignments =
            await (database.select(database.registers)..where(
                  (row) =>
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.assignedDeviceId.equals(normalizedDeviceId) &
                      row.id.equals(registerId).not(),
                ))
                .get();
        for (final prior in priorAssignments) {
          await (database.update(
            database.registers,
          )..where((row) => row.id.equals(prior.id))).write(
            RegistersCompanion(
              assignedDeviceId: const Value(null),
              assignedByUserId: const Value(null),
              assignedAt: const Value(null),
              version: Value(prior.version + 1),
              updatedAt: Value(now),
            ),
          );
        }
        final changed =
            await (database.update(database.registers)..where(
                  (row) =>
                      row.id.equals(register.id) &
                      row.version.equals(expectedVersion),
                ))
                .write(
                  RegistersCompanion(
                    assignedDeviceId: Value(normalizedDeviceId),
                    assignedByUserId: Value(context.actorUserId),
                    assignedAt: Value(now),
                    version: Value(expectedVersion + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) {
          throw const ConflictFailure(
            'The register changed while assigning this device.',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'register',
        entityId: registerId,
        metadata: {'assignedDeviceId': normalizedDeviceId},
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'register.assign_device',
        aggregateType: 'register',
        aggregateId: registerId,
        payload: {
          'registerId': registerId,
          'deviceId': normalizedDeviceId,
          'expectedVersion': expectedVersion,
        },
        now: now,
      ),
    );
  }

  @override
  Future<Result<String, Failure>> openShift({
    required BusinessContext context,
    required OpenShiftDraft draft,
  }) async {
    if (draft.openingCashMinor < 0 || draft.deviceId.trim().isEmpty) {
      return const Result.failure(
        ValidationFailure(
          'Opening cash cannot be negative and a device is required.',
        ),
      );
    }
    final operationId = draft.operationId ?? _idGenerator.newId();
    final existing = await _shiftForOperation(context, operationId);
    if (existing != null) return Result.success(existing.id);
    final shiftId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final register = await _requireRegister(
          database,
          context,
          draft.registerId,
        );
        if (register.assignedDeviceId != draft.deviceId) {
          throw const AuthorizationFailure(
            'This device is not assigned to the selected register.',
            code: 'register-device-mismatch',
          );
        }
        final registerShift =
            await (database.select(database.shifts)..where(
                  (row) =>
                      row.organizationId.equals(context.organizationId) &
                      row.branchId.equals(context.branchId) &
                      row.registerId.equals(draft.registerId) &
                      row.status.equals('open'),
                ))
                .getSingleOrNull();
        if (registerShift != null) {
          throw const ConflictFailure(
            'This register already has an open shift.',
          );
        }
        final branch = await _requireBranch(database, context);
        if (!branch.allowMultipleOpenShiftsPerUser) {
          final userShift =
              await (database.select(database.shifts)..where(
                    (row) =>
                        row.organizationId.equals(context.organizationId) &
                        row.branchId.equals(context.branchId) &
                        row.openedByUserId.equals(context.actorUserId) &
                        row.status.equals('open'),
                  ))
                  .getSingleOrNull();
          if (userShift != null) {
            throw const ConflictFailure(
              'This user already has an open shift in the branch.',
            );
          }
        }
        await database
            .into(database.shifts)
            .insert(
              ShiftsCompanion.insert(
                id: shiftId,
                organizationId: context.organizationId,
                branchId: context.branchId,
                registerId: draft.registerId,
                deviceId: draft.deviceId,
                operationId: operationId,
                openingCashMinor: draft.openingCashMinor,
                openingNotes: Value(_trimmedOrNull(draft.notes)),
                openedByUserId: context.actorUserId,
                openedAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        return shiftId;
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.create,
        entityName: 'shift',
        entityId: shiftId,
        metadata: {
          'registerId': draft.registerId,
          'deviceId': draft.deviceId,
          'openingCashMinor': draft.openingCashMinor,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'shift.open',
        aggregateType: 'shift',
        aggregateId: shiftId,
        payload: {
          'id': shiftId,
          'registerId': draft.registerId,
          'deviceId': draft.deviceId,
          'openingCashMinor': draft.openingCashMinor,
          'notes': draft.notes,
          'openedAt': now.toIso8601String(),
        },
        now: now,
      ),
    );
  }

  @override
  Future<Result<String, Failure>> postCashMovement({
    required BusinessContext context,
    required CashMovementDraft draft,
  }) async {
    final reason = draft.reason.trim();
    if (reason.length < 2 || !_validDirection(draft.type, draft.amountMinor)) {
      return const Result.failure(
        ValidationFailure('Enter a reason and a valid signed movement amount.'),
      );
    }
    final operationId = draft.operationId ?? _idGenerator.newId();
    final existing = await _cashMovementForOperation(context, operationId);
    if (existing != null) return Result.success(existing.id);
    final movementId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final shift = await _requireOpenShift(database, context, draft.shiftId);
        if (shift.openedByUserId != context.actorUserId) {
          throw const AuthorizationFailure(
            'Only the cashier who opened this shift may post drawer movements.',
          );
        }
        await database
            .into(database.cashMovements)
            .insert(
              CashMovementsCompanion.insert(
                id: movementId,
                organizationId: context.organizationId,
                branchId: context.branchId,
                registerId: shift.registerId,
                shiftId: shift.id,
                operationId: operationId,
                movementType: draft.type.databaseValue,
                amountMinor: draft.amountMinor,
                reason: reason,
                createdByUserId: context.actorUserId,
                occurredAt: now,
                createdAt: now,
              ),
            );
        return movementId;
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.create,
        entityName: 'cash_movement',
        entityId: movementId,
        metadata: {
          'shiftId': draft.shiftId,
          'type': draft.type.databaseValue,
          'amountMinor': draft.amountMinor,
          'reason': reason,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'shift.cash_movement',
        aggregateType: 'shift',
        aggregateId: draft.shiftId,
        payload: {
          'id': movementId,
          'shiftId': draft.shiftId,
          'type': draft.type.databaseValue,
          'amountMinor': draft.amountMinor,
          'reason': reason,
          'occurredAt': now.toIso8601String(),
        },
        now: now,
      ),
    );
  }

  @override
  Future<Result<void, Failure>> closeShift({
    required BusinessContext context,
    required CloseShiftDraft draft,
    String? approvedByUserId,
  }) async {
    if (draft.countedAmountsMinor.keys.toSet().length !=
            ShiftPaymentMethod.values.length ||
        !ShiftPaymentMethod.values.every(
          draft.countedAmountsMinor.containsKey,
        ) ||
        draft.countedAmountsMinor.values.any((amount) => amount < 0)) {
      return const Result.failure(
        ValidationFailure(
          'Count every payment method using non-negative amounts.',
        ),
      );
    }
    final operationId = draft.operationId ?? _idGenerator.newId();
    final existing = await _shiftForCloseOperation(context, operationId);
    if (existing != null) return const Result.success(null);
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final shift = await _requireOpenShift(database, context, draft.shiftId);
        if (shift.version != draft.expectedVersion) {
          throw const ConflictFailure(
            'The shift changed. Refresh before closing it.',
          );
        }
        if (shift.openedByUserId != context.actorUserId &&
            approvedByUserId == null) {
          throw const AuthorizationFailure(
            'Closing another user’s shift requires manager approval.',
          );
        }
        final movementTotal = await _cashMovementTotal(database, shift.id);
        final paymentTotals = await _paymentTotals(database, shift.id);
        final expected = <ShiftPaymentMethod, int>{
          ShiftPaymentMethod.cash:
              shift.openingCashMinor +
              movementTotal +
              paymentTotals[ShiftPaymentMethod.cash]!,
          ShiftPaymentMethod.card: paymentTotals[ShiftPaymentMethod.card]!,
          ShiftPaymentMethod.eWallet:
              paymentTotals[ShiftPaymentMethod.eWallet]!,
        };
        final cashCount = draft.countedAmountsMinor[ShiftPaymentMethod.cash]!;
        final cashDiscrepancy = cashCount - expected[ShiftPaymentMethod.cash]!;
        final branch = await _requireBranch(database, context);
        final threshold = branch.cashDiscrepancyApprovalThresholdMinor;
        if (threshold != null &&
            cashDiscrepancy.abs() > threshold &&
            approvedByUserId == null) {
          throw const AuthorizationFailure(
            'This discrepancy exceeds the branch approval threshold.',
            code: 'shift-discrepancy-approval-required',
          );
        }
        for (final method in ShiftPaymentMethod.values) {
          final counted = draft.countedAmountsMinor[method]!;
          final expectedAmount = expected[method]!;
          await database
              .into(database.shiftCounts)
              .insert(
                ShiftCountsCompanion.insert(
                  id: _idGenerator.newId(),
                  organizationId: context.organizationId,
                  branchId: context.branchId,
                  shiftId: shift.id,
                  paymentMethod: method.databaseValue,
                  expectedAmountMinor: expectedAmount,
                  countedAmountMinor: counted,
                  discrepancyMinor: counted - expectedAmount,
                  countedByUserId: context.actorUserId,
                  countedAt: now,
                  createdAt: now,
                ),
              );
        }
        final changed =
            await (database.update(database.shifts)..where(
                  (row) =>
                      row.id.equals(shift.id) &
                      row.status.equals('open') &
                      row.version.equals(draft.expectedVersion),
                ))
                .write(
                  ShiftsCompanion(
                    closeOperationId: Value(operationId),
                    status: const Value('closed'),
                    expectedCashMinor: Value(expected[ShiftPaymentMethod.cash]),
                    countedCashMinor: Value(cashCount),
                    discrepancyMinor: Value(cashDiscrepancy),
                    closingNotes: Value(_trimmedOrNull(draft.notes)),
                    closedByUserId: Value(context.actorUserId),
                    closedAt: Value(now),
                    approvedByUserId: Value(approvedByUserId),
                    approvedAt: Value(approvedByUserId == null ? null : now),
                    approvalNotes: Value(
                      approvedByUserId == null
                          ? null
                          : _trimmedOrNull(draft.approvalNotes),
                    ),
                    version: Value(draft.expectedVersion + 1),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) {
          throw const ConflictFailure(
            'The shift changed while it was being closed.',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'shift',
        entityId: draft.shiftId,
        metadata: {
          'countedAmountsMinor': {
            for (final entry in draft.countedAmountsMinor.entries)
              entry.key.databaseValue: entry.value,
          },
          'approvedByUserId': approvedByUserId,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'shift.close',
        aggregateType: 'shift',
        aggregateId: draft.shiftId,
        payload: {
          'shiftId': draft.shiftId,
          'countedAmountsMinor': {
            for (final entry in draft.countedAmountsMinor.entries)
              entry.key.databaseValue: entry.value,
          },
          'notes': draft.notes,
          'approvedByUserId': approvedByUserId,
          'approvalNotes': draft.approvalNotes,
          'closedAt': now.toIso8601String(),
        },
        now: now,
      ),
    );
  }

  @override
  Future<ShiftPolicy?> getPolicy({required BusinessContext context}) async {
    final branch =
        await (_database.select(_database.branches)..where(
              (row) =>
                  row.id.equals(context.branchId) &
                  row.organizationId.equals(context.organizationId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (branch == null) return null;
    return ShiftPolicy(
      allowMultipleOpenShiftsPerUser: branch.allowMultipleOpenShiftsPerUser,
      allowSalesWithoutOpenShift: branch.allowSalesWithoutOpenShift,
      cashDiscrepancyApprovalThresholdMinor:
          branch.cashDiscrepancyApprovalThresholdMinor,
    );
  }

  @override
  Future<Result<void, Failure>> configurePolicy({
    required BusinessContext context,
    required ShiftPolicy policy,
  }) async {
    final threshold = policy.cashDiscrepancyApprovalThresholdMinor;
    if (threshold != null && threshold < 0) {
      return const Result.failure(
        ValidationFailure('The discrepancy threshold cannot be negative.'),
      );
    }
    final operationId = _idGenerator.newId();
    final now = _clock.nowUtc();
    return _localMutationTransaction.execute(
      businessWrite: (database) async {
        final changed =
            await (database.update(database.branches)..where(
                  (row) =>
                      row.id.equals(context.branchId) &
                      row.organizationId.equals(context.organizationId),
                ))
                .write(
                  BranchesCompanion(
                    allowMultipleOpenShiftsPerUser: Value(
                      policy.allowMultipleOpenShiftsPerUser,
                    ),
                    allowSalesWithoutOpenShift: Value(
                      policy.allowSalesWithoutOpenShift,
                    ),
                    cashDiscrepancyApprovalThresholdMinor: Value(threshold),
                    updatedAt: Value(now),
                  ),
                );
        if (changed != 1) {
          throw const AuthorizationFailure(
            'The active branch is not available locally.',
          );
        }
      },
      auditEntry: _audit(
        context: context,
        operationId: operationId,
        action: AuditActionType.update,
        entityName: 'branch_shift_policy',
        entityId: context.branchId,
        metadata: {
          'allowMultipleOpenShiftsPerUser':
              policy.allowMultipleOpenShiftsPerUser,
          'allowSalesWithoutOpenShift': policy.allowSalesWithoutOpenShift,
          'cashDiscrepancyApprovalThresholdMinor': threshold,
        },
        now: now,
      ),
      outboxCommand: _outbox(
        context: context,
        operationId: operationId,
        commandType: 'branch.shift_policy.update',
        aggregateType: 'branch',
        aggregateId: context.branchId,
        payload: {
          'allowMultipleOpenShiftsPerUser':
              policy.allowMultipleOpenShiftsPerUser,
          'allowSalesWithoutOpenShift': policy.allowSalesWithoutOpenShift,
          'cashDiscrepancyApprovalThresholdMinor': threshold,
        },
        now: now,
      ),
    );
  }

  @override
  Future<Result<CashShift?, Failure>> requireOpenShiftForSale({
    required BusinessContext context,
    required String deviceId,
  }) async {
    final policy = await getPolicy(context: context);
    if (policy == null) {
      return const Result.failure(
        AuthorizationFailure('The active branch is not available locally.'),
      );
    }
    final shift = await watchActiveShift(
      context: context,
      deviceId: deviceId,
    ).first;
    if (shift == null) {
      return policy.allowSalesWithoutOpenShift
          ? const Result.success(null)
          : const Result.failure(
              AuthorizationFailure(
                'Open a shift on this device before processing a sale.',
                code: 'open-shift-required',
              ),
            );
    }
    if (shift.openedByUserId != context.actorUserId) {
      return const Result.failure(
        AuthorizationFailure(
          'This device has a shift opened by another user.',
          code: 'shift-owner-mismatch',
        ),
      );
    }
    return Result.success(shift);
  }

  Future<db.Register> _requireRegister(
    AppDatabase database,
    BusinessContext context,
    String registerId,
  ) async {
    final register =
        await (database.select(database.registers)..where(
              (row) =>
                  row.id.equals(registerId) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (register == null) {
      throw const AuthorizationFailure(
        'The register is unavailable in the active branch.',
      );
    }
    return register;
  }

  Future<db.Branche> _requireBranch(
    AppDatabase database,
    BusinessContext context,
  ) async {
    final branch =
        await (database.select(database.branches)..where(
              (row) =>
                  row.id.equals(context.branchId) &
                  row.organizationId.equals(context.organizationId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (branch == null) {
      throw const AuthorizationFailure(
        'The active branch is not available locally.',
      );
    }
    return branch;
  }

  Future<Shift> _requireOpenShift(
    AppDatabase database,
    BusinessContext context,
    String shiftId,
  ) async {
    final shift =
        await (database.select(database.shifts)..where(
              (row) =>
                  row.id.equals(shiftId) &
                  row.organizationId.equals(context.organizationId) &
                  row.branchId.equals(context.branchId) &
                  row.status.equals('open'),
            ))
            .getSingleOrNull();
    if (shift == null) {
      throw const ConflictFailure('The shift is no longer open.');
    }
    return shift;
  }

  Future<int> _cashMovementTotal(AppDatabase database, String shiftId) async {
    final rows = await (database.select(
      database.cashMovements,
    )..where((row) => row.shiftId.equals(shiftId))).get();
    var total = 0;
    for (final row in rows) {
      total += row.amountMinor;
    }
    return total;
  }

  Future<Map<ShiftPaymentMethod, int>> _paymentTotals(
    AppDatabase database,
    String shiftId,
  ) async {
    final rows = await (database.select(
      database.payments,
    )..where((row) => row.shiftId.equals(shiftId))).get();
    final totals = {for (final method in ShiftPaymentMethod.values) method: 0};
    for (final row in rows) {
      final method = ShiftPaymentMethod.fromDatabase(row.paymentMethod);
      totals[method] = totals[method]! + row.appliedAmountMinor;
    }
    return totals;
  }

  Future<Shift?> _shiftForOperation(
    BusinessContext context,
    String operationId,
  ) {
    return (_database.select(_database.shifts)..where(
          (row) =>
              row.organizationId.equals(context.organizationId) &
              row.operationId.equals(operationId),
        ))
        .getSingleOrNull();
  }

  Future<Shift?> _shiftForCloseOperation(
    BusinessContext context,
    String operationId,
  ) {
    return (_database.select(_database.shifts)..where(
          (row) =>
              row.organizationId.equals(context.organizationId) &
              row.closeOperationId.equals(operationId),
        ))
        .getSingleOrNull();
  }

  Future<db.CashMovement?> _cashMovementForOperation(
    BusinessContext context,
    String operationId,
  ) {
    return (_database.select(_database.cashMovements)..where(
          (row) =>
              row.organizationId.equals(context.organizationId) &
              row.operationId.equals(operationId),
        ))
        .getSingleOrNull();
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
}

bool _validDirection(CashMovementType type, int amountMinor) {
  return switch (type) {
    CashMovementType.cashIn => amountMinor > 0,
    CashMovementType.cashOut || CashMovementType.payout => amountMinor < 0,
    CashMovementType.correction => amountMinor != 0,
  };
}

String _normalizeCode(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
