import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/backend_sync_service.dart';
import '../../../../core/sync/connectivity_monitor.dart';
import '../../../../shared/models/business_context.dart';
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

  Future<Result<void, Failure>> claimCurrentDevice(Register register) async {
    state = const AsyncLoading();
    final deviceId = await ref.read(currentDeviceIdProvider.future);
    if (kIsWeb && !await ref.read(connectivityMonitorProvider).isConnected) {
      const result = Result<void, Failure>.failure(
        NetworkFailure('Browser register claims require an online connection.'),
      );
      _finish(result);
      return result;
    }
    final result = await ref.read(claimRegisterUseCaseProvider)(
      session: ref.read(activeShiftSessionProvider),
      registerId: register.id,
      deviceId: deviceId,
      expectedVersion: register.version,
    );
    if (kIsWeb && result.isSuccess) {
      final value = result.valueOrNull!;
      final session = ref.read(activeShiftSessionProvider)!;
      final businessContext = BusinessContext(
        organizationId: session.activeOrganizationId,
        branchId: session.activeBranchId,
        actorUserId: session.activeOrganization.appUserId,
      );
      final syncResult = await ref
          .read(backendSyncServiceProvider)
          .synchronize(context: businessContext, trigger: SyncTrigger.manual);
      final confirmed = await ref
          .read(registerClaimRepositoryProvider)
          .getInstallationClaim(context: businessContext, deviceId: deviceId);
      if (syncResult.offline || confirmed?.status.name == 'provisional') {
        await ref
            .read(registerClaimRepositoryProvider)
            .discardProvisionalClaim(claimId: value.id, deviceId: deviceId);
        const failure = Result<void, Failure>.failure(
          NetworkFailure(
            'The server did not confirm this browser claim. No register was claimed.',
          ),
        );
        _finish(failure);
        return failure;
      }
      if (confirmed?.status.name == 'rejected') {
        final failure = Result<void, Failure>.failure(
          ConflictFailure(
            confirmed?.rejectionMessage ??
                'Another installation claimed this register first.',
          ),
        );
        _finish(failure);
        return failure;
      }
    }
    _finish(result);
    return result.map((_) {});
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
