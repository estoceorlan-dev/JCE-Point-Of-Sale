import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/offline/credential_vault.dart';
import '../../domain/offline/offline_grant.dart';
import '../../domain/offline/offline_pin_repository.dart';
import '../security/credential_record_store.dart';
import '../security/native_installation_store.dart';

class SecureOfflinePinRepository implements OfflinePinRepository {
  const SecureOfflinePinRepository({
    required this.records,
    required this.installation,
    required this.remote,
    required this.verifier,
    required this.hasher,
    required this.now,
  });
  final CredentialRecordStore records;
  final NativeInstallationStore installation;
  final OfflineEnrollmentSource remote;
  final OfflineGrantVerifier verifier;
  final PinHasher hasher;
  final DateTime Function() now;
  bool _validPin(String pin) => RegExp(r'^\d{6,12}$').hasMatch(pin);
  Result<OfflineGrant, Failure> _failure(String code) => Result.failure(
    AuthenticationFailure(
      'Offline sign-in unavailable. Reconnect and authenticate if required.',
      code: code,
    ),
  );

  @override
  Future<Result<OfflineGrant, Failure>> enroll({
    required String password,
    required String pin,
    required String branchId,
  }) async {
    if (!_validPin(pin)) return _failure('invalid_pin');
    try {
      final device = await installation.load();
      final authorization = await remote.authorize(
        password: password,
        branchId: branchId,
      );
      final time = now().toUtc();
      final grant = verifier.verify(
        authorization,
        deviceId: device.deviceId,
        keyThumbprint: device.key.thumbprint,
        now: time,
      );
      if (grant.branchId != branchId) return _failure('invalid_enrollment');
      final encoded = await hasher.hash(pin);
      return await records.transact((state) async {
        final entries = Map<String, dynamic>.from(
          state['enrollments'] as Map? ?? {},
        );
        final key = '${grant.identityId}:${grant.branchId}';
        final previous = entries[key] as Map?;
        if (previous?['enrollmentId'] == grant.enrollmentId) {
          return _failure('reauthentication_required');
        }
        entries[key] = {
          'enrollmentId': grant.enrollmentId,
          'authorization': authorization,
          'pin': encoded,
          'failures': 0,
          'lockedUntil': null,
          'reauthenticationRequired': false,
        };
        state['enrollments'] = entries;
        state['lastSeenUtc'] = time.millisecondsSinceEpoch;
        state['clockRollback'] = false;
        return Result<OfflineGrant, Failure>.success(grant);
      });
    } on Failure catch (failure) {
      return Result.failure(failure);
    } catch (_) {
      return _failure('credential_storage_or_enrollment_invalid');
    }
  }

  @override
  Future<Result<OfflineGrant, Failure>> signIn({
    required String identityId,
    required String branchId,
    required String pin,
  }) async {
    try {
      final device = await installation.load();
      return await records.transact((state) async {
        final time = now().toUtc();
        final timestamp = time.millisecondsSinceEpoch;
        final lastSeen = state['lastSeenUtc'] as int?;
        if (state['clockRollback'] == true ||
            (lastSeen != null && timestamp < lastSeen)) {
          state['clockRollback'] = true;
          return _failure('clock_rollback');
        }
        state['lastSeenUtc'] = timestamp;
        final entries = state['enrollments'] as Map?;
        final value = entries?['$identityId:$branchId'];
        if (value is! Map) return _failure('not_enrolled');
        final entry = Map<String, dynamic>.from(value);
        if (entry['reauthenticationRequired'] == true) {
          return _failure('reauthentication_required');
        }
        final locked = entry['lockedUntil'] as int?;
        if (locked != null && timestamp < locked) return _failure('pin_locked');
        OfflineGrant grant;
        try {
          grant = verifier.verify(
            entry['authorization'] as String,
            deviceId: device.deviceId,
            keyThumbprint: device.key.thumbprint,
            now: time,
          );
          if (grant.identityId != identityId || grant.branchId != branchId) {
            return _failure('invalid_enrollment');
          }
        } catch (_) {
          return _failure('enrollment_expired_or_invalid');
        }
        final valid =
            _validPin(pin) &&
            await hasher.verify(
              pin,
              Map<String, String>.from(entry['pin'] as Map),
            );
        if (!valid) {
          final failures = (entry['failures'] as int) + 1;
          entry['failures'] = failures;
          if (failures >= 10) {
            entry['reauthenticationRequired'] = true;
          } else if (failures == 5) {
            entry['lockedUntil'] = time
                .add(const Duration(minutes: 15))
                .millisecondsSinceEpoch;
          }
          entries!['$identityId:$branchId'] = entry;
          return _failure(
            failures >= 10
                ? 'reauthentication_required'
                : failures == 5
                ? 'pin_locked'
                : 'invalid_pin',
          );
        }
        entry['failures'] = 0;
        entry['lockedUntil'] = null;
        entries!['$identityId:$branchId'] = entry;
        return Result<OfflineGrant, Failure>.success(grant);
      });
    } catch (_) {
      return _failure('credential_storage_or_enrollment_invalid');
    }
  }

  @override
  Future<Result<OfflineGrant, Failure>> validateActive(
    OfflineGrant grant,
  ) async {
    try {
      final device = await installation.load();
      return await records.transact((state) async {
        final time = now().toUtc();
        final timestamp = time.millisecondsSinceEpoch;
        final lastSeen = state['lastSeenUtc'] as int?;
        if (state['clockRollback'] == true ||
            (lastSeen != null && timestamp < lastSeen)) {
          state['clockRollback'] = true;
          return _failure('clock_rollback');
        }
        state['lastSeenUtc'] = timestamp;
        final entry =
            (state['enrollments']
                    as Map?)?['${grant.identityId}:${grant.branchId}']
                as Map?;
        if (entry == null ||
            entry['enrollmentId'] != grant.enrollmentId ||
            entry['reauthenticationRequired'] == true) {
          return _failure('reauthentication_required');
        }
        try {
          return Result<OfflineGrant, Failure>.success(
            verifier.verify(
              entry['authorization'] as String,
              deviceId: device.deviceId,
              keyThumbprint: device.key.thumbprint,
              now: time,
            ),
          );
        } catch (_) {
          return _failure('enrollment_expired_or_invalid');
        }
      });
    } catch (_) {
      return _failure('credential_storage_or_enrollment_invalid');
    }
  }
}
