import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import 'offline_grant.dart';

abstract interface class OfflineEnrollmentSource {
  // This must obtain a new grant from the API using password reauthentication.
  // Neither a cached grant nor a refreshed local timestamp may renew enrollment.
  Future<String> authorize({
    required String password,
    required String branchId,
  });
}

abstract interface class OfflinePinRepository {
  Future<Result<OfflineGrant, Failure>> enroll({
    required String password,
    required String pin,
    required String branchId,
  });
  Future<Result<OfflineGrant, Failure>> signIn({
    required String identityId,
    required String branchId,
    required String pin,
  });
  Future<Result<OfflineGrant, Failure>> validateActive(OfflineGrant grant);
}
