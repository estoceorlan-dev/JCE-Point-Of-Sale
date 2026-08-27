import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_audit_repository.dart';
import '../repositories/auth_repository.dart';

class RefreshAccessUseCase {
  const RefreshAccessUseCase({
    required AuthRepository authRepository,
    required AuthAuditRepository auditRepository,
  }) : _authRepository = authRepository,
       _auditRepository = auditRepository;

  final AuthRepository _authRepository;
  final AuthAuditRepository _auditRepository;

  Future<Result<AuthSession, Failure>> call(AuthSession previous) async {
    final result = await _authRepository.refreshAccess();
    if (result case FailureResult<AuthSession, Failure>()) {
      return result;
    }
    final value = result.valueOrNull!;
    try {
      if (roleSignature(previous) != roleSignature(value)) {
        await _auditRepository.recordRoleChange(
          previous: previous,
          current: value,
        );
      }
      return result;
    } catch (error, stackTrace) {
      return Result<AuthSession, Failure>.failure(
        FailureMapper.fromException(error, stackTrace),
      );
    }
  }

  static String roleSignature(AuthSession session) {
    final roleCodes = session.roles.map((role) => role.code).toList()..sort();
    final permissions =
        session.permissions.map((permission) => permission.code).toList()
          ..sort();
    return [...roleCodes, '|', ...permissions].join(',');
  }
}
