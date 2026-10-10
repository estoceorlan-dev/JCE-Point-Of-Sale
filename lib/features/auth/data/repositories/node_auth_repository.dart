import 'dart:async';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/sync/node_actor_evidence.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/offline/offline_pin_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/device_registration_repository.dart';
import '../datasources/access_local_data_source.dart';
import '../dto/node_access_mapper.dart';
import 'native_api_session_repository.dart';

class NodeAuthRepository implements AuthRepository {
  NodeAuthRepository(
    this.sessions,
    this.devices,
    this.local,
    this.actor,
    this.pins,
  ) {
    _changes = StreamController<Result<AuthSession?, Failure>>.broadcast(
      onListen: () => unawaited(_restore()),
    );
  }
  final NativeApiSessionRepository sessions;
  final DeviceRegistrationRepository devices;
  final AccessLocalDataSource local;
  final NodeActorEvidence actor;
  final OfflinePinRepository pins;
  late final StreamController<Result<AuthSession?, Failure>> _changes;
  AuthSession? _current;
  bool _offline = false;
  @override
  Stream<Result<AuthSession?, Failure>> authStateChanges() => _changes.stream;
  Future<void> _restore() async {
    try {
      final result = await _online();
      if (!_changes.isClosed) _changes.add(Result.success(result));
    } catch (_) {
      // Never turn a cached online account into an offline session without its PIN.
      actor.clear();
      if (!_changes.isClosed) _changes.add(const Result.success(null));
    }
  }

  Future<AuthSession> _online({String? branchId}) async {
    final access = await sessions.authenticated(
      '/v1/auth/access',
      method: 'GET',
    );
    if (access['deploymentId'] != sessions.records.deploymentId) {
      throw const AuthenticationFailure('Deployment mismatch.');
    }
    final boundBranch = await sessions.records.transact(
      (state) async => (state['deviceScope'] as Map?)?['branchId'] as String?,
    );
    final session = nodeAccessSession(
      access,
      branchId: branchId ?? boundBranch,
    );
    await devices.register(session);
    await actor.activateOnline(session);
    await local.replaceProfile(session.user);
    await sessions.records.transact((state) async {
      final profiles = Map<String, dynamic>.from(
        state['accessProfiles'] as Map? ?? {},
      );
      profiles[session.user.identityId] = access;
      state['accessProfiles'] = profiles;
    });
    _current = session;
    _offline = false;
    return session;
  }

  Future<Result<AuthSession, Failure>> _attempt(
    Future<AuthSession> Function() work,
  ) async {
    try {
      return Result.success(await work());
    } on Failure catch (failure) {
      return Result.failure(failure);
    } catch (error, stack) {
      return Result.failure(
        AuthenticationFailure(
          'Unable to open the local account. Check the installation profile and assigned branch.',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }

  @override
  Future<Result<AuthSession, Failure>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => _attempt(() async {
    actor.clear();
    final result = await sessions.signIn(email, password);
    if (result.failureOrNull case final failure?) throw failure;
    return _online();
  });
  Future<Result<AuthSession, Failure>> signInWithPin({
    required String identityId,
    required String branchId,
    required String pin,
  }) => _attempt(() async {
    final result = await pins.signIn(
      identityId: identityId,
      branchId: branchId,
      pin: pin,
    );
    if (result.failureOrNull case final failure?) throw failure;
    final grant = result.valueOrNull!;
    final profile = await sessions.records.transact(
      (state) async => (state['accessProfiles'] as Map?)?[identityId],
    );
    if (profile is! Map ||
        profile['userId'] != grant.userId ||
        profile['organizationId'] != grant.organizationId) {
      throw const AuthenticationFailure(
        'Reconnect to finish enrolling this account.',
      );
    }
    final session = nodeAccessSession(
      Map<String, dynamic>.from(profile),
      branchId: branchId,
      offline: grant,
    );
    await sessions.records.transact((state) async {
      state.remove('session');
    });
    await actor.activateOffline(session, grant);
    _current = session;
    _offline = true;
    _changes.add(Result.success(session));
    return session;
  });
  Future<List<({String identityId, String branchId, String label})>>
  enrolledAccounts() => sessions.records.transact((state) async {
    final profiles = state['accessProfiles'] as Map? ?? {};
    final entries = state['enrollments'] as Map? ?? {};
    return [
      for (final key in entries.keys.cast<String>())
        if (profiles[key.split(':').first] is Map)
          (
            identityId: key.split(':').first,
            branchId: key.split(':').last,
            label:
                (profiles[key.split(':').first] as Map)['displayName']
                    as String,
          ),
    ];
  });
  Future<Result<void, Failure>> enrollPin(String password, String pin) async {
    final current = _current;
    if (current == null || _offline) {
      return const Result.failure(
        AuthenticationFailure('Sign in online to enroll.'),
      );
    }
    final result = await pins.enroll(
      password: password,
      pin: pin,
      branchId: current.activeBranchId,
    );
    return result.fold(
      onSuccess: (_) => const Result.success(null),
      onFailure: Result.failure,
    );
  }

  @override
  Future<Result<AuthSession, Failure>> selectActiveBranch({
    required String organizationId,
    required String branchId,
  }) => _attempt(() async {
    if (_offline || _current?.activeOrganizationId != organizationId) {
      throw const AuthorizationFailure('Reconnect before changing branches.');
    }
    return _online(branchId: branchId);
  });
  @override
  Future<Result<AuthSession, Failure>> refreshAccess() => _attempt(() async {
    if (_offline) {
      final result = await actor.verifyCanStart(_current!);
      if (result.failureOrNull case final failure?) throw failure;
      return _current!;
    }
    return _online(branchId: _current?.activeBranchId);
  });
  @override
  Future<Result<void, Failure>> sendPasswordResetEmail(String email) async =>
      const Result.failure(
        AuthenticationFailure(
          'Ask your administrator for a one-time account recovery token.',
        ),
      );
  @override
  Future<Result<void, Failure>> signOut() async {
    if (actor.transport.web) {
      final result = await sessions.signOut();
      if (result.isFailure) return result;
    }
    actor.clear();
    _current = null;
    _offline = false;
    try {
      if (!actor.transport.web) await sessions.signOut();
    } catch (_) {
      /* Local logout remains available during an outage. */
    }
    await sessions.records.transact((state) async {
      state.remove('session');
    });
    _changes.add(const Result.success(null));
    return const Result.success(null);
  }

  @override
  Future<void> dispose() async {
    actor.clear();
    await _changes.close();
  }
}
