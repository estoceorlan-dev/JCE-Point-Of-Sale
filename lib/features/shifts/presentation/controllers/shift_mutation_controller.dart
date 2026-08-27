import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/cash_movement.dart';
import '../../domain/entities/cash_shift.dart';
import '../../domain/entities/register.dart';
import '../providers/shift_providers.dart';

final shiftMutationControllerProvider =
    AsyncNotifierProvider<ShiftMutationController, void>(
      ShiftMutationController.new,
    );

class ShiftMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<String, Failure>> createRegister(RegisterDraft draft) async {
    state = const AsyncLoading();
    final result = await ref.read(createRegisterUseCaseProvider)(
      session: ref.read(activeShiftSessionProvider),
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> assignCurrentDevice(Register register) async {
    state = const AsyncLoading();
    final deviceId = await ref.read(currentDeviceIdProvider.future);
    final result = await ref.read(assignRegisterDeviceUseCaseProvider)(
      session: ref.read(activeShiftSessionProvider),
      registerId: register.id,
      deviceId: deviceId,
      expectedVersion: register.version,
    );
    _finish(result);
    return result;
  }

  Future<Result<String, Failure>> openShift(OpenShiftDraft draft) async {
    state = const AsyncLoading();
    final result = await ref.read(openShiftUseCaseProvider)(
      session: ref.read(activeShiftSessionProvider),
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<String, Failure>> postMovement(CashMovementDraft draft) async {
    state = const AsyncLoading();
    final result = await ref.read(postCashMovementUseCaseProvider)(
      session: ref.read(activeShiftSessionProvider),
      draft: draft,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> closeShift(
    CloseShiftDraft draft, {
    bool approveAsManager = false,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(closeShiftUseCaseProvider)(
      session: ref.read(activeShiftSessionProvider),
      draft: draft,
      approveAsManager: approveAsManager,
    );
    _finish(result);
    return result;
  }

  Future<Result<void, Failure>> configurePolicy(ShiftPolicy policy) async {
    state = const AsyncLoading();
    final result = await ref.read(configureShiftPolicyUseCaseProvider)(
      session: ref.read(activeShiftSessionProvider),
      policy: policy,
    );
    _finish(result);
    ref.invalidate(shiftPolicyProvider);
    return result;
  }

  void _finish<S>(Result<S, Failure> result) {
    state = result.fold(
      onSuccess: (_) => const AsyncData(null),
      onFailure: (failure) =>
          AsyncError(failure, failure.stackTrace ?? StackTrace.current),
    );
  }
}
