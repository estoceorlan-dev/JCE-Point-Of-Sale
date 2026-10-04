import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/services/firebase_app_check_initializer.dart';
import '../../domain/entities/register_claim_action_grant.dart';
import '../../domain/repositories/register_claim_authorization_service.dart';

class FirebaseRegisterClaimAuthorizationService
    implements RegisterClaimAuthorizationService {
  const FirebaseRegisterClaimAuthorizationService({
    required String functionName,
    required String region,
    required AppConfig config,
  }) : _functionName = functionName,
       _region = region,
       _config = config;

  final String _functionName;
  final String _region;
  final AppConfig _config;

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
      await const FirebaseAppCheckInitializer().initialize(
        app: secondaryApp,
        config: _config,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      if (kIsWeb) await secondaryAuth.setPersistence(Persistence.NONE);
      final credential = await secondaryAuth.signInWithEmailAndPassword(
        email: managerEmail.trim(),
        password: managerPassword,
      );
      if (credential.user?.emailVerified != true) {
        return const Result.failure(
          AuthenticationFailure('Verify the manager email before approving.'),
        );
      }
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
        } catch (_) {
          // The primary cashier auth context is a different Firebase app and
          // is never touched by this cleanup.
        }
        // Deletion must still run when sign-out fails (for example offline).
        try {
          await secondaryApp.delete();
        } catch (_) {
          // Keep the primary cashier session isolated from cleanup failures.
        }
      }
    }
  }
}
