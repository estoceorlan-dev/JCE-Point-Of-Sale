import '../../error/failure.dart';
import '../../error/result.dart';
import '../../../shared/models/business_context.dart';
import 'approval_challenge.dart';
import 'approval_grant.dart';

/// The implementation must authenticate the supervisor online for enrollment,
/// derive allowed scope on the server, and retain PINs only transiently.
/// A cashier's session or a typed user ID is never enrollment authorization.
abstract interface class SupervisorApprovalService {
  Future<Result<void, Failure>> enroll({
    required BusinessContext context,
    required String deviceId,
    required String pin,
  });

  /// Verify device-bound credential, PIN lockout, signature, scope and expiry;
  /// persist signed operation evidence securely before returning metadata.
  /// Checkout must consume the grant in the same transaction as the operation.
  Future<Result<ApprovalGrant, Failure>> approve({
    required ApprovalChallenge challenge,
    required String credentialId,
    required String pin,
  });
}
