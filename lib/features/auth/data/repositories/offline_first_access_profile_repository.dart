import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/app_clock.dart';
import '../../../../shared/models/app_user.dart';
import '../../domain/repositories/access_profile_repository.dart';
import '../datasources/access_local_data_source.dart';
import '../datasources/access_remote_data_source.dart';

class OfflineFirstAccessProfileRepository implements AccessProfileRepository {
  OfflineFirstAccessProfileRepository({
    required AccessLocalDataSource local,
    required AccessRemoteDataSource remote,
    required AppClock clock,
    required Duration maxOfflineAge,
  }) : _local = local,
       _remote = remote,
       _clock = clock,
       _maxOfflineAge = maxOfflineAge;

  final AccessLocalDataSource _local;
  final AccessRemoteDataSource _remote;
  final AppClock _clock;
  final Duration _maxOfflineAge;
  final StreamController<AccessProfileEvent> _events =
      StreamController<AccessProfileEvent>.broadcast();
  final Map<String, StreamSubscription<AppUser?>> _localSubscriptions = {};

  @override
  Stream<AccessProfileEvent> get events => _events.stream;

  @override
  Future<Result<AppUser?, Failure>> loadProfile({
    required String firebaseUid,
    required String email,
    bool forceRefresh = false,
  }) async {
    _watchLocalBranchProfiles(firebaseUid);
    final cached = await _local.findByFirebaseUid(firebaseUid);
    final cacheIsCurrent =
        cached != null && await _isOfflineAccessCurrent(firebaseUid);

    if (!forceRefresh && cacheIsCurrent) {
      unawaited(
        _fetchRemote(
          firebaseUid: firebaseUid,
          email: email,
          cached: cached,
          allowCachedFallback: true,
          publish: true,
        ),
      );
      return Result<AppUser?, Failure>.success(cached);
    }

    return _fetchRemote(
      firebaseUid: firebaseUid,
      email: email,
      cached: cached,
      allowCachedFallback: cacheIsCurrent,
      publish: false,
    );
  }

  Future<Result<AppUser?, Failure>> _fetchRemote({
    required String firebaseUid,
    required String email,
    required AppUser? cached,
    required bool allowCachedFallback,
    required bool publish,
  }) async {
    try {
      final remote = await _remote.fetchCurrentProfile(
        firebaseUid: firebaseUid,
        email: email,
      );
      if (remote == null) {
        return _revoke(
          firebaseUid,
          const AuthorizationFailure(
            'No JCE POS application profile is assigned to this account.',
            code: 'profile-not-found',
          ),
          publish: publish,
        );
      }
      await _local.replaceProfile(remote);
      await _local.recordVerifiedAt(firebaseUid, _clock.nowUtc());
      final merged = await _local.findByFirebaseUid(firebaseUid);
      final result = Result<AppUser?, Failure>.success(merged ?? remote);
      if (publish) {
        _publish(firebaseUid, result);
      }
      return result;
    } on AccessProfileRejectedException catch (error) {
      final failure = error.reason == 'unauthenticated'
          ? AuthenticationFailure(
              'Your authenticated session is no longer valid.',
              code: error.reason,
              cause: error,
            )
          : AuthorizationFailure(
              'This account is no longer authorized to use JCE POS.',
              code: error.reason,
              cause: error,
            );
      return _revoke(firebaseUid, failure, publish: publish);
    } on AccessProfileUnavailableException catch (error) {
      if (allowCachedFallback && cached != null) {
        return Result<AppUser?, Failure>.success(cached);
      }
      final failure = NetworkFailure(
        'Access could not be verified. Connect to the internet and try again.',
        code: error.reason,
        cause: error.cause ?? error,
      );
      final result = Result<AppUser?, Failure>.failure(failure);
      if (publish) {
        _publish(firebaseUid, result);
      }
      return result;
    } catch (error, stackTrace) {
      final failure = FailureMapper.fromException(error, stackTrace);
      final result = Result<AppUser?, Failure>.failure(failure);
      if (publish) {
        _publish(firebaseUid, result);
      }
      return result;
    }
  }

  Future<Result<AppUser?, Failure>> _revoke(
    String firebaseUid,
    Failure failure, {
    required bool publish,
  }) async {
    await _local.clearProfile(firebaseUid);
    final result = Result<AppUser?, Failure>.failure(failure);
    if (publish) {
      _publish(firebaseUid, result);
    }
    return result;
  }

  Future<bool> _isOfflineAccessCurrent(String firebaseUid) async {
    final lastVerifiedAt = await _local.lastVerifiedAt(firebaseUid);
    if (lastVerifiedAt == null) {
      return false;
    }
    return !_clock.nowUtc().isAfter(lastVerifiedAt.add(_maxOfflineAge));
  }

  void _publish(String firebaseUid, Result<AppUser?, Failure> result) {
    if (!_events.isClosed) {
      _events.add(AccessProfileEvent(firebaseUid: firebaseUid, result: result));
    }
  }

  void _watchLocalBranchProfiles(String firebaseUid) {
    if (_localSubscriptions.containsKey(firebaseUid)) {
      return;
    }
    var initialSnapshot = true;
    _localSubscriptions[firebaseUid] = _local
        .watchBranchProfilesByFirebaseUid(firebaseUid)
        .listen(
          (profile) {
            if (initialSnapshot) {
              initialSnapshot = false;
              return;
            }
            _publish(firebaseUid, Result<AppUser?, Failure>.success(profile));
          },
          onError: (Object error, StackTrace stackTrace) {
            _publish(
              firebaseUid,
              Result<AppUser?, Failure>.failure(
                FailureMapper.fromException(error, stackTrace),
              ),
            );
          },
        );
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _localSubscriptions.values) {
      await subscription.cancel();
    }
    await _events.close();
  }
}
