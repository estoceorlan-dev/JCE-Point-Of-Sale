import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/register_claim_action_grant.dart';

abstract interface class RegisterClaimAuthorizationService {
  Future<Result<RegisterClaimActionGrant, Failure>> authorize({
    required String managerEmail,
    required String managerPassword,
    required String organizationId,
    required String branchId,
    required String conflictId,
    required String targetRegisterId,
    required String deviceId,
    required String requestedByUserId,
    required String nonce,
  });
}
