import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../auth/domain/services/account_action_service.dart';
import '../../domain/services/staff_invitation_service.dart';

class NodeStaffInvitationService implements StaffInvitationService {
  const NodeStaffInvitationService(this.actions);
  final AccountActionService actions;
  @override
  Future<Result<String, Failure>> generateLink({
    required String organizationId,
    required String userId,
  }) async {
    final result = await actions.issue(userId: userId, recovery: false);
    return result.fold(
      onSuccess: (value) => Result.success(
        'Activation token: ${value.token}\nExpires: ${value.expiresAt.toLocal()}',
      ),
      onFailure: Result.failure,
    );
  }

  @override
  Future<Result<void, Failure>> accept({
    required String organizationId,
  }) async => const Result.failure(
    AuthenticationFailure(
      'Use the account activation form with your administrator-issued token.',
    ),
  );
}
