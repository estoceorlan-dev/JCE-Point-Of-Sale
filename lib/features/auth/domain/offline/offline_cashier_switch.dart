import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../entities/logout_readiness.dart';
import 'offline_grant.dart';
import 'offline_pin_repository.dart';

typedef InspectCashierExit =
    Future<Result<LogoutReadiness, Failure>> Function(OfflineGrant current);

class OfflineCashierSwitch {
  OfflineCashierSwitch(this.pins, this.inspectExit);
  final OfflinePinRepository pins;
  final InspectCashierExit inspectExit;
  OfflineGrant? _current;
  OfflineGrant? get current => _current;
  Future<void> _tail = Future.value();
  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Result<OfflineGrant, Failure>> signIn({
    required String identityId,
    required String branchId,
    required String pin,
  }) => _serialize(() async {
    final previous = _current;
    if (previous != null) {
      final check = await inspectExit(previous);
      if (check.isFailure) return Result.failure(check.failureOrNull!);
      final readiness = check.valueOrNull!;
      if (readiness.openShiftCount > 0 || readiness.checkoutRecoveryCount > 0) {
        return const Result.failure(
          AuthorizationFailure(
            'Close the current shift and finish payment recovery before switching.',
          ),
        );
      }
      // Pending operations retain their original actor; switching never clears the outbox.
    }
    final result = await pins.signIn(
      identityId: identityId,
      branchId: branchId,
      pin: pin,
    );
    if (result.isSuccess) _current = result.valueOrNull;
    return result;
  });

  Future<Result<void, Failure>> signOut() => _serialize(() async {
    final previous = _current;
    if (previous != null) {
      final result = await inspectExit(previous);
      if (result.isFailure) return Result.failure(result.failureOrNull!);
      if (!result.valueOrNull!.canLogout) {
        return Result.failure(
          AuthorizationFailure(result.valueOrNull!.blockerMessage),
        );
      }
    }
    _current = null;
    return const Result.success(null);
  });
}
