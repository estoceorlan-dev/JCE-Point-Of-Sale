import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/business_context.dart';
import '../entities/register_claim.dart';
import '../entities/register_claim_action_grant.dart';

abstract interface class RegisterClaimRepository {
  Stream<RegisterClaim?> watchInstallationClaim({
    required BusinessContext context,
    required String deviceId,
  });

  Future<RegisterClaim?> getInstallationClaim({
    required BusinessContext context,
    required String deviceId,
  });

  Future<Result<RegisterClaim, Failure>> claim({
    required BusinessContext context,
    required String registerId,
    required String deviceId,
    required int expectedVersion,
  });

  Future<Result<void, Failure>> resolve({
    required BusinessContext context,
    required String claimId,
    required String targetRegisterId,
    RegisterClaimActionGrant? managerGrant,
  });

  Future<Result<void, Failure>> release({
    required BusinessContext context,
    required String registerId,
    required String deviceId,
  });

  Future<void> discardProvisionalClaim({
    required String claimId,
    required String deviceId,
  });

  Future<void> applyResolutionDirective({
    required String organizationId,
    required String branchId,
    required String claimId,
    required String targetRegisterId,
    required String deviceId,
    required String? managerUserId,
    required DateTime resolvedAt,
  });
}
