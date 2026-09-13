import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_audit_repository.dart';
import '../repositories/auth_repository.dart';

class SignOutUseCase {
  const SignOutUseCase({
    required AuthRepository authRepository,
    required AuthAuditRepository auditRepository,
  }) : _authRepository = authRepository,
       _auditRepository = auditRepository;

  final AuthRepository _authRepository;
  final AuthAuditRepository _auditRepository;

  Future<Result<void, Failure>> call(AuthSession? session) async {
    if (session != null) {
      try {
        await _auditRepository.recordLogout(session);
      } catch (_) {
        // A best-effort audit write must never retain an authenticated session.
      }
    }
    try {
      return _authRepository.signOut();
    } catch (error, stackTrace) {
      return Result<void, Failure>.failure(
        FailureMapper.fromException(error, stackTrace),
      );
    }
  }
}
