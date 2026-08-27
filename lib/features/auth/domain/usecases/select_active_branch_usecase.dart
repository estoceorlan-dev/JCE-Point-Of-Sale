import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_audit_repository.dart';
import '../repositories/auth_repository.dart';

class SelectActiveBranchUseCase {
  const SelectActiveBranchUseCase({
    required AuthRepository authRepository,
    required AuthAuditRepository auditRepository,
  }) : _authRepository = authRepository,
       _auditRepository = auditRepository;

  final AuthRepository _authRepository;
  final AuthAuditRepository _auditRepository;

  Future<Result<AuthSession, Failure>> call({
    required AuthSession previous,
    required String organizationId,
    required String branchId,
  }) async {
    final result = await _authRepository.selectActiveBranch(
      organizationId: organizationId,
      branchId: branchId,
    );
    if (result case FailureResult<AuthSession, Failure>()) {
      return result;
    }
    final value = result.valueOrNull!;
    try {
      if (previous.activeOrganizationId != value.activeOrganizationId ||
          previous.activeBranchId != value.activeBranchId) {
        await _auditRepository.recordBranchSwitch(
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
}
