import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/register_claim_action_grant.dart';
import '../../domain/repositories/register_claim_authorization_service.dart';

class FirebaseRegisterClaimAuthorizationService
    implements RegisterClaimAuthorizationService {
  const FirebaseRegisterClaimAuthorizationService({
    required String functionName,
    required String region,
  }) : _functionName = functionName,
       _region = region;

  final String _functionName;
  final String _region;

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
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'manager-action-${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      await secondaryAuth.signInWithEmailAndPassword(
        email: managerEmail.trim(),
        password: managerPassword,
      );
      final functions = FirebaseFunctions.instanceFor(
        app: secondaryApp,
        region: _region,
      );
      final response = await functions.httpsCallable(_functionName).call({
        'organizationId': organizationId,
        'branchId': branchId,
        'conflictId': conflictId,
        'targetRegisterId': targetRegisterId,
        'deviceId': deviceId,
        'requestedByUserId': requestedByUserId,
        'nonce': nonce,
      });
      final value = Map<String, Object?>.from(response.data as Map);
      return Result.success(
        RegisterClaimActionGrant(
          id: value['grantId'] as String,
          nonce: nonce,
          managerUserId: value['managerUserId'] as String,
          expiresAt: DateTime.parse(value['expiresAt'] as String).toUtc(),
        ),
      );
    } catch (error, stackTrace) {
      return Result.failure(FailureMapper.fromException(error, stackTrace));
    } finally {
      if (secondaryApp != null) {
        try {
          await FirebaseAuth.instanceFor(app: secondaryApp).signOut();
          await secondaryApp.delete();
        } catch (_) {
          // The primary cashier auth context is a different Firebase app and
          // is never touched by this cleanup.
        }
      }
    }
  }
}
