import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/app_user.dart';

abstract interface class AccessProfileRepository {
  Stream<AccessProfileEvent> get events;

  Future<Result<AppUser?, Failure>> loadProfile({
    required String firebaseUid,
    required String email,
    bool forceRefresh = false,
  });

  Future<void> dispose();
}

class AccessProfileEvent {
  const AccessProfileEvent({required this.firebaseUid, required this.result});

  final String firebaseUid;
  final Result<AppUser?, Failure> result;
}
