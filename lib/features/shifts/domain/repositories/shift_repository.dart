import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/cash_movement.dart';
import '../entities/cash_shift.dart';
import '../entities/register.dart';

abstract interface class ShiftRepository {
  Stream<List<Register>> watchRegisters({required BusinessContext context});

  Stream<CashShift?> watchActiveShift({
    required BusinessContext context,
    required String deviceId,
  });

  Stream<List<CashShift>> watchRecentShifts({required BusinessContext context});

  Future<CashShift?> getShift({
    required BusinessContext context,
    required String shiftId,
  });

  Future<Result<String, Failure>> createRegister({
    required BusinessContext context,
    required RegisterDraft draft,
  });

  Future<Result<void, Failure>> assignDevice({
    required BusinessContext context,
    required String registerId,
    required String deviceId,
    required int expectedVersion,
  });

  Future<Result<String, Failure>> openShift({
    required BusinessContext context,
    required OpenShiftDraft draft,
  });

  Future<Result<String, Failure>> postCashMovement({
    required BusinessContext context,
    required CashMovementDraft draft,
  });

  Future<Result<void, Failure>> closeShift({
    required BusinessContext context,
    required CloseShiftDraft draft,
    String? approvedByUserId,
  });

  Future<ShiftPolicy?> getPolicy({required BusinessContext context});

  Future<Result<void, Failure>> configurePolicy({
    required BusinessContext context,
    required ShiftPolicy policy,
  });

  Future<Result<CashShift?, Failure>> requireOpenShiftForSale({
    required BusinessContext context,
    required String deviceId,
  });
}
