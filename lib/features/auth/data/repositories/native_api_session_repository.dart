import 'package:uuid/uuid.dart';
import '../../../../core/remote/remote_api_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../datasources/native_auth_api.dart';
import '../security/credential_record_store.dart';
import '../../domain/offline/native_session_repository.dart';

// Transport/session adapter prepared for Phase 4; the Firebase provider remains active.
class NativeApiSessionRepository implements NativeSessionRepository {
  const NativeApiSessionRepository(this.api, this.records);
  final NativeAuthApi api;
  final CredentialRecordStore records;

  void _checkDeployment(Map<String, dynamic> value) {
    if (value['deploymentId'] != records.deploymentId) {
      throw const AuthenticationFailure(
        'The API belongs to a different deployment.',
        code: 'deployment_mismatch',
      );
    }
  }

  @override
  Future<Result<NativeAccess, Failure>> signIn(
    String email,
    String password,
  ) async {
    try {
      final tokens = await api.request(
        '/v1/auth/login',
        body: {
          'email': email,
          'password': password,
          'organizationCode': api.profile.organizationCode,
          'clientType': 'native',
        },
      );
      _checkDeployment(tokens);
      final access = await api.request(
        '/v1/auth/access',
        method: 'GET',
        accessToken: tokens['accessToken'] as String,
      );
      _checkDeployment(access);
      await records.transact((state) async {
        state['session'] = {
          ...tokens,
          'generation': const Uuid().v4(),
          'identityId': access['identityId'],
          'organizationId': access['organizationId'],
          'userId': access['userId'],
        };
      });
      return Result.success(
        NativeAccess(
          deploymentId: access['deploymentId'] as String,
          identityId: access['identityId'] as String,
          userId: access['userId'] as String,
          organizationId: access['organizationId'] as String,
          displayName: access['displayName'] as String,
          organizationPermissions: Set.unmodifiable(
            (access['organizationPermissions'] as List).cast<String>(),
          ),
          branches: List.unmodifiable(
            (access['branches'] as List).map(
              (value) => NativeBranchAccess(
                value['id'] as String,
                value['name'] as String,
                Set.unmodifiable((value['permissions'] as List).cast<String>()),
              ),
            ),
          ),
        ),
      );
    } on Failure catch (failure) {
      return Result.failure(failure);
    } catch (_) {
      return const Result.failure(
        AuthenticationFailure(
          'Protected credential storage is unavailable.',
          code: 'storage_unavailable',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> authenticated(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
    bool syncRequest = false,
  }) async {
    final session = await records.transact(
      (state) async => state['session'] == null
          ? null
          : Map<String, dynamic>.from(state['session'] as Map),
    );
    if (session == null) {
      throw const AuthenticationFailure(
        'Sign in to the API first.',
        code: 'unauthorized',
      );
    }
    try {
      return await api.request(
        path,
        method: method,
        body: body,
        accessToken: session['accessToken'] as String,
        headers: headers,
        syncRequest: syncRequest,
      );
    } catch (failure) {
      if (failure is! AuthenticationFailure &&
          !(failure is RemoteApiException && failure.status == 401)) {
        rethrow;
      }
      if (failure is AuthenticationFailure && failure.code != 'unauthorized') {
        rethrow;
      }
      final updated = await _refresh(session);
      return api.request(
        path,
        method: method,
        body: body,
        accessToken: updated['accessToken'] as String,
        headers: headers,
        syncRequest: syncRequest,
      );
    }
  }

  Future<Map<String, dynamic>> _refresh(Map<String, dynamic> previous) async {
    // Serialize across callers. Rotation retries must not reuse an already spent token.
    final result = await records
        .transact<Result<Map<String, dynamic>, Failure>>((state) async {
          final current = state['session'] as Map?;
          if (current == null ||
              current['generation'] != previous['generation']) {
            return const Result.failure(
              AuthenticationFailure(
                'The active session changed.',
                code: 'session_changed',
              ),
            );
          }
          if (current['refreshToken'] != previous['refreshToken']) {
            return Result.success(Map<String, dynamic>.from(current));
          }
          try {
            final next = await api.request(
              '/v1/auth/refresh',
              body: {'refreshToken': current['refreshToken']},
            );
            _checkDeployment(next);
            final updated = {...Map<String, dynamic>.from(current), ...next};
            state['session'] = updated;
            return Result.success(updated);
          } on AuthenticationFailure catch (failure) {
            if (failure.code != 'rate_limited') {
              state.remove('session');
              final enrollments = state['enrollments'] as Map?;
              for (final entry
                  in enrollments?.entries ?? <MapEntry<dynamic, dynamic>>[]) {
                if ((entry.key as String).startsWith(
                  '${current['identityId']}:',
                )) {
                  (entry.value as Map)['reauthenticationRequired'] = true;
                }
              }
            }
            return Result.failure(failure);
          } on Failure catch (failure) {
            return Result.failure(failure);
          }
        });
    return result.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => throw failure,
    );
  }

  @override
  Future<Result<void, Failure>> signOut() async {
    try {
      await authenticated('/v1/auth/logout');
      await records.transact((state) async {
        state.remove('session');
      });
      return const Result.success(null);
    } on Failure catch (failure) {
      return Result.failure(failure);
    } catch (_) {
      return const Result.failure(
        AuthenticationFailure(
          'Protected credential storage is unavailable.',
          code: 'storage_unavailable',
        ),
      );
    }
  }
}
