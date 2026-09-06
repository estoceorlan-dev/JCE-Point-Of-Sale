import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';

abstract interface class StaffInvitationService {
  Future<Result<String, Failure>> generateLink({
    required String organizationId,
    required String userId,
  });

  Future<Result<void, Failure>> accept({required String organizationId});
}
