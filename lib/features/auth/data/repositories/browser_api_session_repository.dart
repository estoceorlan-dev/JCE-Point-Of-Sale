import '../../../../core/error/failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/remote/remote_api_exception.dart';
import '../../domain/offline/native_session_repository.dart';
import '../security/browser_session_platform.dart';
import 'native_api_session_repository.dart';

class BrowserApiSessionRepository extends NativeApiSessionRepository {
  BrowserApiSessionRepository(super.api, super.records) {
    requireBrowserOrigin(api.profile.apiOrigin);
  }
  Future<void>? _refreshing;
  Map<String, String> get _csrf => {
    if (browserCsrf() case final value?) 'X-CSRF-Token': value,
  };
  @override
  Future<Result<NativeAccess, Failure>> signIn(
    String email,
    String password,
  ) async {
    try {
      final result = await api.request(
        '/v1/auth/login',
        body: {
          'clientType': 'web',
          'organizationCode': api.profile.organizationCode,
          'email': email,
          'password': password,
        },
      );
      if (result['deploymentId'] != records.deploymentId) {
        throw const AuthenticationFailure('Deployment mismatch.');
      }
      final value = await authenticated('/v1/auth/access', method: 'GET');
      return Result.success(
        NativeAccess(
          deploymentId: value['deploymentId'] as String,
          identityId: value['identityId'] as String,
          userId: value['userId'] as String,
          organizationId: value['organizationId'] as String,
          displayName: value['displayName'] as String,
          organizationPermissions: (value['organizationPermissions'] as List)
              .cast<String>()
              .toSet(),
          branches: (value['branches'] as List)
              .map(
                (b) => NativeBranchAccess(
                  b['id'] as String,
                  b['name'] as String,
                  (b['permissions'] as List).cast<String>().toSet(),
                ),
              )
              .toList(),
        ),
      );
    } on Failure catch (failure) {
      return Result.failure(failure);
    }
  }

  @override
  Future<Map<String, dynamic>> authenticated(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
    bool syncRequest = false,
  }) async {
    try {
      return await api.request(
        path,
        method: method,
        body: body,
        headers: {...headers, ..._csrf},
        syncRequest: syncRequest,
      );
    } catch (error) {
      if (!(error is AuthenticationFailure && error.code == 'unauthorized') &&
          !(error is RemoteApiException && error.status == 401)) {
        rethrow;
      }
      await (_refreshing ??= api
          .request('/v1/auth/refresh', body: {}, headers: _csrf)
          .then<void>((_) {})
          .whenComplete(() => _refreshing = null));
      return api.request(
        path,
        method: method,
        body: body,
        headers: {...headers, ..._csrf},
        syncRequest: syncRequest,
      );
    }
  }

  @override
  Future<Result<void, Failure>> signOut() async {
    try {
      await authenticated('/v1/auth/logout');
      return const Result.success(null);
    } on Failure catch (failure) {
      return Result.failure(failure);
    }
  }
}
