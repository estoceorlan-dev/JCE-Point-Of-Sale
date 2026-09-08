import '../../error/failure.dart';
import '../../error/failures.dart';
import '../../error/result.dart';
import '../../../shared/models/business_context.dart';
import '../domain/approval_challenge.dart';
import '../domain/approval_grant.dart';
import '../domain/supervisor_approval_service.dart';

/// Fail closed on every platform until enrollment, secure storage, local atomic
/// consumption and backend evidence validation are all implemented and accepted.
class UnavailableSupervisorApprovalService
    implements SupervisorApprovalService {
  const UnavailableSupervisorApprovalService();

  static const _failure = AuthorizationFailure(
    'Offline supervisor approvals are not available on this device.',
    code: 'offline-approvals-unavailable',
  );

  @override
  Future<Result<void, Failure>> enroll({
    required BusinessContext context,
    required String deviceId,
    required String pin,
  }) async => const Result.failure(_failure);

  @override
  Future<Result<ApprovalGrant, Failure>> approve({
    required ApprovalChallenge challenge,
    required String credentialId,
    required String pin,
  }) async => const Result.failure(_failure);
}
