import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/services/account_action_service.dart';
import 'native_api_session_repository.dart';

class NodeAccountActionService implements AccountActionService {
  const NodeAccountActionService(this.sessions);
  final NativeApiSessionRepository sessions;
  @override
  Future<Result<IssuedAccountAction, Failure>> issue({
    required String userId,
    required bool recovery,
  }) async {
    try {
      final result = await sessions.authenticated(
        recovery ? '/v1/staff/password-resets' : '/v1/staff/activation-tokens',
        body: {'userId': userId},
      );
      return Result.success(
        IssuedAccountAction(
          result['token'] as String,
          DateTime.parse(result['expiresAt'] as String),
        ),
      );
    } on Failure catch (failure) {
      return Result.failure(failure);
    } catch (_) {
      return const Result.failure(
        UnexpectedFailure('The account service returned an invalid response.'),
      );
    }
  }

  @override
  Future<Result<void, Failure>> complete({
    required String token,
    required String password,
    required bool recovery,
  }) async {
    try {
      await sessions.api.request(
        recovery
            ? '/v1/staff/password-resets/complete'
            : '/v1/staff/invitations/accept',
        body: {'token': token, 'password': password},
      );
      return const Result.success(null);
    } on Failure catch (failure) {
      return Result.failure(failure);
    } catch (_) {
      return const Result.failure(
        UnexpectedFailure('Account activation or recovery failed.'),
      );
    }
  }
}
