import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../../../../core/error/failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/models/app_user.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/access_profile_repository.dart';
import '../../domain/repositories/active_context_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/device_registration_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required firebase.FirebaseAuth firebaseAuth,
    required AccessProfileRepository accessProfileRepository,
    required ActiveContextRepository activeContextRepository,
    required DeviceRegistrationRepository deviceRegistrationRepository,
    required Duration accessRefreshInterval,
  }) : _firebaseAuth = firebaseAuth,
       _accessProfileRepository = accessProfileRepository,
       _activeContextRepository = activeContextRepository,
       _deviceRegistrationRepository = deviceRegistrationRepository,
       _accessRefreshInterval = accessRefreshInterval {
    _changes = StreamController<Result<AuthSession?, Failure>>.broadcast(
      onListen: _start,
    );
  }

  final firebase.FirebaseAuth _firebaseAuth;
  final AccessProfileRepository _accessProfileRepository;
  final ActiveContextRepository _activeContextRepository;
  final DeviceRegistrationRepository _deviceRegistrationRepository;
  final Duration _accessRefreshInterval;
  late final StreamController<Result<AuthSession?, Failure>> _changes;

  StreamSubscription<firebase.User?>? _firebaseSubscription;
  StreamSubscription<AccessProfileEvent>? _profileSubscription;
  Timer? _refreshTimer;
  AuthSession? _currentSession;
  Failure? _pendingSignOutFailure;
  bool _started = false;
  bool _refreshing = false;

  @override
  Stream<Result<AuthSession?, Failure>> authStateChanges() => _changes.stream;

  void _start() {
    if (_started) {
      return;
    }
    _started = true;
    _profileSubscription = _accessProfileRepository.events.listen(
      (event) => unawaited(_handleProfileEvent(event)),
    );
    _firebaseSubscription = _firebaseAuth.userChanges().listen(
      (user) => unawaited(_handleFirebaseUser(user)),
      onError: (Object error, StackTrace stackTrace) {
        _emitFailure(FailureMapper.fromException(error, stackTrace));
      },
    );
  }

  @override
  Future<Result<AuthSession, Failure>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return const Result<AuthSession, Failure>.failure(
          AuthenticationFailure(
            'Firebase did not return an authenticated user.',
            code: 'missing-user',
          ),
        );
      }
      final result = await _resolve(firebaseUser, forceRefresh: true);
      if (result case SuccessResult<AuthSession, Failure>(:final value)) {
        await _activate(value, emit: false);
        return result;
      }
      await _signOutForFailure(firebaseUser.uid, result.failureOrNull!);
      return result;
    } on firebase.FirebaseAuthException catch (error, stackTrace) {
      return Result<AuthSession, Failure>.failure(
        _failureForFirebase(error, stackTrace),
      );
    } catch (error, stackTrace) {
      return Result<AuthSession, Failure>.failure(
        FailureMapper.fromException(error, stackTrace),
      );
    }
  }

  @override
  Future<Result<AuthSession, Failure>> selectActiveBranch({
    required String organizationId,
    required String branchId,
  }) async {
    final current = _currentSession;
    if (current == null) {
      return const Result<AuthSession, Failure>.failure(
        AuthenticationFailure('Authentication is required.'),
      );
    }
    try {
      final updated = current.switchTo(
        organizationId: organizationId,
        branchId: branchId,
      );
      await _activeContextRepository.save(updated);
      _currentSession = updated;
      return Result<AuthSession, Failure>.success(updated);
    } on ArgumentError catch (error, stackTrace) {
      return Result<AuthSession, Failure>.failure(
        AuthorizationFailure(
          'The selected branch is not assigned to this account.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      return Result<AuthSession, Failure>.failure(
        FailureMapper.fromException(error, stackTrace),
      );
    }
  }

  @override
  Future<Result<AuthSession, Failure>> refreshAccess() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return const Result<AuthSession, Failure>.failure(
        AuthenticationFailure('Authentication is required.'),
      );
    }
    final result = await _resolve(firebaseUser, forceRefresh: true);
    if (result case SuccessResult<AuthSession, Failure>(:final value)) {
      await _activate(value, emit: false);
      return result;
    }
    await _signOutForFailure(firebaseUser.uid, result.failureOrNull!);
    return result;
  }

  @override
  Future<Result<void, Failure>> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      return const Result<void, Failure>.success(null);
    } on firebase.FirebaseAuthException catch (error, stackTrace) {
      return Result<void, Failure>.failure(
        _failureForFirebase(error, stackTrace),
      );
    } catch (error, stackTrace) {
      return Result<void, Failure>.failure(
        FailureMapper.fromException(error, stackTrace),
      );
    }
  }

  @override
  Future<Result<void, Failure>> signOut() async {
    _pendingSignOutFailure = null;
    _currentSession = null;
    _stopRefreshTimer();
    try {
      await _firebaseAuth.signOut();
      return const Result<void, Failure>.success(null);
    } catch (error, stackTrace) {
      return Result<void, Failure>.failure(
        FailureMapper.fromException(error, stackTrace),
      );
    }
  }

  Future<Result<AuthSession, Failure>> _resolve(
    firebase.User firebaseUser, {
    required bool forceRefresh,
  }) async {
    final email = firebaseUser.email?.trim();
    if (email == null || email.isEmpty) {
      return const Result<AuthSession, Failure>.failure(
        AuthenticationFailure(
          'The Firebase account does not have an email address.',
          code: 'missing-email',
        ),
      );
    }
    final profileResult = await _accessProfileRepository.loadProfile(
      firebaseUid: firebaseUser.uid,
      email: email,
      forceRefresh: forceRefresh,
    );
    return _restoreSession(profileResult);
  }

  Future<Result<AuthSession, Failure>> _restoreSession(
    Result<AppUser?, Failure> profileResult,
  ) async {
    if (profileResult case FailureResult<AppUser?, Failure>(:final failure)) {
      return Result<AuthSession, Failure>.failure(failure);
    }
    final profile = profileResult.valueOrNull;
    if (profile == null) {
      return const Result<AuthSession, Failure>.failure(
        AuthorizationFailure(
          'No JCE POS application profile is assigned to this account.',
          code: 'profile-not-found',
        ),
      );
    }
    try {
      return Result<AuthSession, Failure>.success(
        await _activeContextRepository.restore(profile),
      );
    } on StateError catch (error, stackTrace) {
      return Result<AuthSession, Failure>.failure(
        AuthorizationFailure(
          'No active branch assignment is available for this account.',
          code: 'no-active-assignment',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      return Result<AuthSession, Failure>.failure(
        FailureMapper.fromException(error, stackTrace),
      );
    }
  }

  Future<void> _handleFirebaseUser(firebase.User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentSession = null;
      _stopRefreshTimer();
      final failure = _pendingSignOutFailure;
      _pendingSignOutFailure = null;
      if (failure == null) {
        _emit(const Result<AuthSession?, Failure>.success(null));
      } else {
        _emit(Result<AuthSession?, Failure>.failure(failure));
      }
      return;
    }

    final result = await _resolve(firebaseUser, forceRefresh: false);
    if (result case SuccessResult<AuthSession, Failure>(:final value)) {
      await _activate(value, emit: true);
      return;
    }
    await _signOutForFailure(firebaseUser.uid, result.failureOrNull!);
  }

  Future<void> _handleProfileEvent(AccessProfileEvent event) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null || firebaseUser.uid != event.firebaseUid) {
      return;
    }
    final result = await _restoreSession(event.result);
    if (result case SuccessResult<AuthSession, Failure>(:final value)) {
      await _activate(value, emit: true);
      return;
    }
    await _signOutForFailure(firebaseUser.uid, result.failureOrNull!);
  }

  Future<void> _activate(AuthSession session, {required bool emit}) async {
    _currentSession = session;
    _startRefreshTimer();
    await _deviceRegistrationRepository.register(session);
    if (emit) {
      _emit(Result<AuthSession?, Failure>.success(session));
    }
  }

  void _startRefreshTimer() {
    _refreshTimer ??= Timer.periodic(
      _accessRefreshInterval,
      (_) => unawaited(_refreshCurrentAccess()),
    );
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refreshCurrentAccess() async {
    if (_refreshing) {
      return;
    }
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return;
    }
    _refreshing = true;
    try {
      final result = await _resolve(firebaseUser, forceRefresh: true);
      if (result case SuccessResult<AuthSession, Failure>(:final value)) {
        await _activate(value, emit: true);
      } else {
        await _signOutForFailure(firebaseUser.uid, result.failureOrNull!);
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _signOutForFailure(String firebaseUid, Failure failure) async {
    _pendingSignOutFailure = failure;
    _currentSession = null;
    _stopRefreshTimer();
    await _activeContextRepository.clear(firebaseUid);
    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      _pendingSignOutFailure = null;
      _emitFailure(failure);
    }
  }

  Failure _failureForFirebase(
    firebase.FirebaseAuthException error,
    StackTrace stackTrace,
  ) {
    if (error.code == 'network-request-failed') {
      return NetworkFailure(
        'The network is unavailable. Connect once to authenticate this device.',
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return AuthenticationFailure(
      _messageForFirebaseCode(error.code),
      code: error.code,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  String _messageForFirebaseCode(String code) {
    return switch (code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email or password is incorrect.',
      'user-disabled' => 'This Firebase account has been disabled.',
      'too-many-requests' =>
        'Too many attempts were made. Please wait before trying again.',
      'invalid-email' => 'Enter a valid email address.',
      _ => 'Authentication could not be completed.',
    };
  }

  void _emitFailure(Failure failure) {
    _emit(Result<AuthSession?, Failure>.failure(failure));
  }

  void _emit(Result<AuthSession?, Failure> result) {
    if (!_changes.isClosed) {
      _changes.add(result);
    }
  }

  @override
  Future<void> dispose() async {
    _stopRefreshTimer();
    await _firebaseSubscription?.cancel();
    await _profileSubscription?.cancel();
    await _changes.close();
  }
}
