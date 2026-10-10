import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';

class IssuedAccountAction {
  const IssuedAccountAction(this.token, this.expiresAt);
  final String token;
  final DateTime expiresAt;
}

abstract interface class AccountActionService {
  Future<Result<IssuedAccountAction, Failure>> issue({
    required String userId,
    required bool recovery,
  });
  Future<Result<void, Failure>> complete({
    required String token,
    required String password,
    required bool recovery,
  });
}
