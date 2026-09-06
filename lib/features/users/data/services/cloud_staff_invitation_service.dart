import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/services/staff_invitation_service.dart';

class CloudStaffInvitationService implements StaffInvitationService {
  const CloudStaffInvitationService({
    required FirebaseFunctions functions,
    required String generateFunctionName,
    required String acceptFunctionName,
    required bool demoMode,
  }) : _functions = functions,
       _generateFunctionName = generateFunctionName,
       _acceptFunctionName = acceptFunctionName,
       _demoMode = demoMode;

  final FirebaseFunctions _functions;
  final String _generateFunctionName;
  final String _acceptFunctionName;
  final bool _demoMode;

  @override
  Future<Result<String, Failure>> generateLink({
    required String organizationId,
    required String userId,
  }) async {
    if (_demoMode) {
      return const Result.failure(
        NetworkFailure(
          'Invite links require a connected Firebase environment.',
        ),
      );
    }
    try {
      final response = await _functions
          .httpsCallable(_generateFunctionName)
          .call({'organizationId': organizationId, 'userId': userId});
      final data = response.data;
      if (data is! Map || data['inviteUrl'] is! String) {
        return const Result.failure(
          UnexpectedFailure('The invite service returned an invalid response.'),
        );
      }
      return Result.success(data['inviteUrl'] as String);
    } catch (error, stackTrace) {
      return Result.failure(FailureMapper.fromException(error, stackTrace));
    }
  }

  @override
  Future<Result<void, Failure>> accept({required String organizationId}) async {
    if (_demoMode) {
      return const Result.failure(
        NetworkFailure(
          'Invite acceptance requires a connected Firebase environment.',
        ),
      );
    }
    try {
      await _functions.httpsCallable(_acceptFunctionName).call({
        'organizationId': organizationId,
      });
      return const Result.success(null);
    } catch (error, stackTrace) {
      return Result.failure(FailureMapper.fromException(error, stackTrace));
    }
  }
}
