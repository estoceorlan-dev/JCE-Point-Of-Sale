import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../data/repositories/node_auth_repository.dart';
import '../providers/auth_providers.dart';

final enrolledCashiersProvider = FutureProvider((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository is NodeAuthRepository
      ? repository.enrolledAccounts()
      : Future.value(<({String identityId, String branchId, String label})>[]);
});
final offlinePinControllerProvider = Provider(
  (ref) => OfflinePinController(ref),
);

class OfflinePinController {
  const OfflinePinController(this.ref);
  final Ref ref;
  Future<Result<void, Failure>> submit({
    String? identityId,
    String? branchId,
    String? password,
    required String pin,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    if (repository is! NodeAuthRepository) {
      return const Result.failure(
        AuthenticationFailure('Offline PIN sign-in is unavailable.'),
      );
    }
    if (password != null) {
      final result = await repository.enrollPin(password, pin);
      ref.invalidate(enrolledCashiersProvider);
      return result;
    }
    final result = await repository.signInWithPin(
      identityId: identityId!,
      branchId: branchId!,
      pin: pin,
    );
    if (result.valueOrNull case final session?) {
      await ref.read(authAuditRepositoryProvider).recordLogin(session);
    }
    return result.fold(
      onSuccess: (_) => const Result.success(null),
      onFailure: Result.failure,
    );
  }
}
