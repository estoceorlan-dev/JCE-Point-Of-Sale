import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/cash_movement.dart' as domain;
import '../../domain/entities/cash_shift.dart' as domain;
import '../../domain/entities/register.dart' as domain;

class ShiftLocalDataSource {
  const ShiftLocalDataSource(this._database);

  final AppDatabase _database;

  Stream<List<domain.Register>> watchRegisters({
    required String organizationId,
    required String branchId,
  }) {
    final query = _database.select(_database.registers)
      ..where(
        (row) =>
            row.organizationId.equals(organizationId) &
            row.branchId.equals(branchId) &
            row.deletedAt.isNull(),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.name)]);
    return query.watch().map(
      (rows) => rows.map(_mapRegister).toList(growable: false),
    );
  }

  Stream<domain.CashShift?> watchActiveShift({
    required String organizationId,
    required String branchId,
    required String deviceId,
  }) {
    final shifts = _database.shifts;
    final registers = _database.registers;
    final movements = _database.cashMovements;
    final payments = _database.payments;
    final query =
        _database.select(shifts).join([
            innerJoin(
              registers,
              registers.id.equalsExp(shifts.registerId) &
                  registers.organizationId.equalsExp(shifts.organizationId) &
                  registers.branchId.equalsExp(shifts.branchId),
            ),
            leftOuterJoin(movements, movements.shiftId.equalsExp(shifts.id)),
            leftOuterJoin(payments, payments.shiftId.equalsExp(shifts.id)),
          ])
          ..where(
            shifts.organizationId.equals(organizationId) &
                shifts.branchId.equals(branchId) &
                shifts.deviceId.equals(deviceId) &
                shifts.status.equals('open'),
          )
          ..groupBy([shifts.id])
          ..orderBy([OrderingTerm.desc(shifts.openedAt)])
          ..limit(1);
    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;
      return _hydrate(
        rows.single.readTable(shifts),
        rows.single.readTable(registers).name,
      );
    });
  }

  Stream<List<domain.CashShift>> watchRecentShifts({
    required String organizationId,
    required String branchId,
  }) {
    final shifts = _database.shifts;
    final registers = _database.registers;
    final movements = _database.cashMovements;
    final counts = _database.shiftCounts;
    final payments = _database.payments;
    final query =
        _database.select(shifts).join([
            innerJoin(
              registers,
              registers.id.equalsExp(shifts.registerId) &
                  registers.organizationId.equalsExp(shifts.organizationId) &
                  registers.branchId.equalsExp(shifts.branchId),
            ),
            leftOuterJoin(movements, movements.shiftId.equalsExp(shifts.id)),
            leftOuterJoin(counts, counts.shiftId.equalsExp(shifts.id)),
            leftOuterJoin(payments, payments.shiftId.equalsExp(shifts.id)),
          ])
          ..where(
            shifts.organizationId.equals(organizationId) &
                shifts.branchId.equals(branchId),
          )
          ..groupBy([shifts.id])
          ..orderBy([OrderingTerm.desc(shifts.openedAt)])
          ..limit(30);
    return query.watch().asyncMap((rows) async {
      final result = <domain.CashShift>[];
      for (final row in rows) {
        result.add(
          await _hydrate(row.readTable(shifts), row.readTable(registers).name),
        );
      }
      return result;
    });
  }

  Future<domain.CashShift?> getShift({
    required String organizationId,
    required String branchId,
    required String shiftId,
  }) async {
    final shifts = _database.shifts;
    final registers = _database.registers;
    final query =
        _database.select(shifts).join([
          innerJoin(
            registers,
            registers.id.equalsExp(shifts.registerId) &
                registers.organizationId.equalsExp(shifts.organizationId) &
                registers.branchId.equalsExp(shifts.branchId),
          ),
        ])..where(
          shifts.id.equals(shiftId) &
              shifts.organizationId.equals(organizationId) &
              shifts.branchId.equals(branchId),
        );
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _hydrate(row.readTable(shifts), row.readTable(registers).name);
  }

  domain.Register _mapRegister(Register row) {
    return domain.Register(
      id: row.id,
      organizationId: row.organizationId,
      branchId: row.branchId,
      code: row.code,
      name: row.name,
      assignedDeviceId: row.assignedDeviceId,
      isActive: row.isActive,
      version: row.version,
    );
  }

  Future<domain.CashShift> _hydrate(Shift shift, String registerName) async {
    final movementRows =
        await (_database.select(_database.cashMovements)
              ..where((row) => row.shiftId.equals(shift.id))
              ..orderBy([(row) => OrderingTerm.asc(row.occurredAt)]))
            .get();
    final countRows =
        await (_database.select(_database.shiftCounts)
              ..where((row) => row.shiftId.equals(shift.id))
              ..orderBy([(row) => OrderingTerm.asc(row.paymentMethod)]))
            .get();
    final paymentRows = await (_database.select(
      _database.payments,
    )..where((row) => row.shiftId.equals(shift.id))).get();
    return domain.CashShift(
      id: shift.id,
      registerId: shift.registerId,
      registerName: registerName,
      deviceId: shift.deviceId,
      status: domain.CashShiftStatus.fromDatabase(shift.status),
      openingCashMinor: shift.openingCashMinor,
      openedByUserId: shift.openedByUserId,
      openedAt: shift.openedAt,
      movements: movementRows
          .map(
            (row) => domain.CashMovement(
              id: row.id,
              shiftId: row.shiftId,
              type: domain.CashMovementType.fromDatabase(row.movementType),
              amountMinor: row.amountMinor,
              reason: row.reason,
              createdByUserId: row.createdByUserId,
              occurredAt: row.occurredAt,
            ),
          )
          .toList(growable: false),
      counts: countRows
          .map(
            (row) => domain.ShiftCount(
              paymentMethod: domain.ShiftPaymentMethod.fromDatabase(
                row.paymentMethod,
              ),
              expectedAmountMinor: row.expectedAmountMinor,
              countedAmountMinor: row.countedAmountMinor,
              discrepancyMinor: row.discrepancyMinor,
            ),
          )
          .toList(growable: false),
      version: shift.version,
      cashSalesMinor: _paymentTotal(paymentRows, 'cash'),
      cardSalesMinor: _paymentTotal(paymentRows, 'card'),
      eWalletSalesMinor: _paymentTotal(paymentRows, 'e_wallet'),
      expectedCashMinorAtClose: shift.expectedCashMinor,
      countedCashMinor: shift.countedCashMinor,
      discrepancyMinor: shift.discrepancyMinor,
      closedByUserId: shift.closedByUserId,
      closedAt: shift.closedAt,
      approvedByUserId: shift.approvedByUserId,
      approvedAt: shift.approvedAt,
      approvalNotes: shift.approvalNotes,
    );
  }
}

int _paymentTotal(List<Payment> payments, String method) {
  var total = 0;
  for (final payment in payments) {
    if (payment.paymentMethod == method) total += payment.appliedAmountMinor;
  }
  return total;
}
