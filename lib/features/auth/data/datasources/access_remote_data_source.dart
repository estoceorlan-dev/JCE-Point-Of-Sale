import '../../../../shared/models/app_user.dart';

abstract interface class AccessRemoteDataSource {
  Future<AppUser?> fetchCurrentProfile({
    required String firebaseUid,
    required String email,
  });
}

class AccessProfileRejectedException implements Exception {
  const AccessProfileRejectedException(this.reason);

  final String reason;
}

class AccessProfileUnavailableException implements Exception {
  const AccessProfileUnavailableException(this.reason, {this.cause});

  final String reason;
  final Object? cause;
}
