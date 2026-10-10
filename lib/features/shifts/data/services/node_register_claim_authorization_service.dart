import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../auth/data/datasources/native_auth_api.dart';
import '../../domain/entities/register_claim_action_grant.dart';
import '../../domain/repositories/register_claim_authorization_service.dart';

class NodeRegisterClaimAuthorizationService
    implements RegisterClaimAuthorizationService {
  const NodeRegisterClaimAuthorizationService(this.api);
  final NativeAuthApi api;
  @override
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
  }) async {
    String? access;
    try {
      // Isolated, temporary supervisor session: never replace the cashier's credentials.
      final login = await api.request(
        '/v1/auth/login',
        body: {
          'clientType': 'native',
          'organizationCode': api.profile.organizationCode,
          'email': managerEmail,
          'password': managerPassword,
        },
      );
      access = login['accessToken'] as String;
      final value = await api.request(
        '/v1/register-claims/authorizations',
        accessToken: access,
        body: {
          'branchId': branchId,
          'conflictId': conflictId,
          'targetRegisterId': targetRegisterId,
          'deviceId': deviceId,
          'requestedByUserId': requestedByUserId,
          'nonce': nonce,
        },
      );
      return Result.success(
        RegisterClaimActionGrant(
          id: value['grantId'] as String,
          nonce: nonce,
          managerUserId: value['managerUserId'] as String,
          expiresAt: DateTime.parse(value['expiresAt'] as String).toUtc(),
        ),
      );
    } catch (error, stack) {
      return Result.failure(FailureMapper.fromException(error, stack));
    } finally {
      if (access != null) {
        try {
          await api.request('/v1/auth/logout', accessToken: access);
        } catch (_) {
          /* Short-lived session expires server-side. */
        }
      }
    }
  }
}
