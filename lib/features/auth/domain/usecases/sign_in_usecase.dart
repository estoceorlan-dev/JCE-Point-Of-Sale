import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_audit_repository.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase({
    required AuthRepository authRepository,
    required AuthAuditRepository auditRepository,
  }) : _authRepository = authRepository,
       _auditRepository = auditRepository;

  final AuthRepository _authRepository;
  final AuthAuditRepository _auditRepository;

  Future<Result<AuthSession, Failure>> call({
    required String email,
    required String password,
  }) async {
    final result = await _authRepository.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    try {
      if (result case SuccessResult<AuthSession, Failure>(:final value)) {
        await _auditRepository.recordLogin(value);
      } else {
        final failure = result.failureOrNull!;
        await _auditRepository.recordLoginFailed(
          email,
          reason: _failureCode(failure),
        );
      }
      return result;
    } catch (error, stackTrace) {
      return Result<AuthSession, Failure>.failure(
        FailureMapper.fromException(error, stackTrace),
      );
    }
  }

  String? _failureCode(Failure failure) {
    return switch (failure) {
      AuthenticationFailure(:final code) => code,
      AuthorizationFailure(:final code) => code,
      NetworkFailure(:final code) => code,
      _ => failure.type.name,
    };
  }
}
