import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/services/staff_invitation_service.dart';

/// Token delivery/activation UI belongs to feature parity; no Firebase fallback.
class OperatorStaffInvitationService implements StaffInvitationService {
  const OperatorStaffInvitationService();
  @override
  Future<Result<String, Failure>> generateLink({
    required String organizationId,
    required String userId,
  }) async => const Result.failure(
    ValidationFailure(
      'Use the Node staff activation workflow to issue a one-time activation token.',
    ),
  );
  @override
  Future<Result<void, Failure>> accept({
    required String organizationId,
  }) async => const Result.failure(
    ValidationFailure(
      'Activate this account using the administrator-issued token.',
    ),
  );
}
