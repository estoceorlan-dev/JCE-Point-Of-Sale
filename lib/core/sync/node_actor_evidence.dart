import 'dart:convert';
import '../../features/auth/data/security/native_installation_store.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/domain/offline/offline_grant.dart';
import '../../features/auth/domain/offline/offline_pin_repository.dart';
import '../../features/auth/domain/repositories/operational_access_policy.dart';
import '../database/models/outbox_command.dart';
import '../error/failure.dart';
import '../error/failures.dart';
import '../error/result.dart';
import 'canonical_json.dart';
import 'node_device_transport.dart';

/// Active authority is memory-only. Queued evidence is immutable and survives logout.
class NodeActorEvidence implements OperationalAccessPolicy {
  NodeActorEvidence(this.transport, this.installation, this.pins);
  final NodeDeviceTransport transport;
  final NativeInstallationStore installation;
  final OfflinePinRepository pins;
  String? _authorization;
  OfflineGrant? _offline;
  AuthSession? _session;
  int _generation = 0;

  void clear() {
    _generation++;
    _authorization = null;
    _offline = null;
    _session = null;
  }

  Future<void> activateOnline(AuthSession session) async {
    clear();
    final generation = _generation;
    final token = transport.web
        ? 'browser-cookie'
        : await transport.authorizeActor();
    if (generation != _generation) {
      throw const AuthenticationFailure('The active cashier changed.');
    }
    _authorization = token;
    _session = session;
  }

  Future<void> activateOffline(AuthSession session, OfflineGrant grant) async {
    clear();
    final generation = _generation;
    final token = await installation.records.transact(
      (state) async =>
          ((state['enrollments']
                      as Map)['${grant.identityId}:${grant.branchId}']
                  as Map)['authorization']
              as String,
    );
    if (generation != _generation) {
      throw const AuthenticationFailure('The active cashier changed.');
    }
    _authorization = token;
    _offline = grant;
    _session = session;
  }

  Map<String, dynamic> _claims() =>
      jsonDecode(
            utf8.decode(
              base64Url.decode(
                base64Url.normalize(_authorization!.split('.')[1]),
              ),
            ),
          )
          as Map<String, dynamic>;
  Future<void> _validate() async {
    if (_session == null || _authorization == null) {
      throw const AuthenticationFailure('Sign in before starting new work.');
    }
    if (transport.web) {
      final access = await transport.sessions.authenticated(
        '/v1/auth/access',
        method: 'GET',
      );
      if (access['identityId'] != _session!.user.identityId) {
        throw const AuthenticationFailure(
          'The active browser account changed.',
        );
      }
      return;
    }
    final offline = _offline;
    if (offline != null) {
      final result = await pins.validateActive(offline);
      if (result.failureOrNull case final failure?) throw failure;
    } else if (DateTime.now().toUtc().millisecondsSinceEpoch >=
        (_claims()['exp'] as int) * 1000 - 30000) {
      final generation = _generation;
      final next = await transport.authorizeActor();
      if (generation != _generation) {
        throw const AuthenticationFailure('The active cashier changed.');
      }
      _authorization = next;
    }
  }

  @override
  Future<Result<void, Failure>> verifyCanStart(AuthSession session) async {
    try {
      await _validate();
      if (_session?.user.identityId != session.user.identityId ||
          _session?.activeBranchId != session.activeBranchId) {
        throw const AuthenticationFailure('The active cashier changed.');
      }
      return const Result.success(null);
    } on Failure catch (failure) {
      return Result.failure(failure);
    }
  }

  Future<String> sign(OutboxCommand command) async {
    final generation = _generation;
    await _validate();
    if (generation != _generation) {
      throw const AuthenticationFailure('The active cashier changed.');
    }
    final token = _authorization!;
    final session = _session!;
    final claims = transport.web ? {'iat': 0, 'exp': 9007199254740} : _claims();
    final created = command.createdAt.toUtc();
    if (command.actorUserId != session.activeOrganization.appUserId ||
        command.organizationId != session.activeOrganizationId ||
        command.branchId != session.activeBranchId ||
        created.millisecondsSinceEpoch <
            (claims['iat'] as int) * 1000 - 120000 ||
        created.millisecondsSinceEpoch >= (claims['exp'] as int) * 1000) {
      throw const AuthorizationFailure(
        'The command is outside this cashier authorization.',
      );
    }
    final device = transport.web ? null : await installation.load();
    final body = <String, dynamic>{
      'identityId': session.user.identityId,
      'operationId': command.operationId,
      'organizationId': command.organizationId,
      'branchId': command.branchId,
      'deviceId': device?.deviceId,
      'commandType': command.commandType,
      'aggregateType': command.aggregateType,
      'aggregateId': command.aggregateId,
      'createdAt': created.toIso8601String(),
      'payload': command.payload,
    };
    if (generation != _generation) {
      throw const AuthenticationFailure('The active cashier changed.');
    }
    final signature = device?.key.sign(
      jsonEncode([
        'jce-command-v1',
        installation.records.deploymentId,
        jsonDigest(body),
        token,
      ]),
    );
    return jsonEncode({
      'deploymentId': installation.records.deploymentId,
      'body': {
        ...body,
        if (!transport.web)
          'actorEvidence': {'authorization': token, 'signature': signature},
      },
    });
  }
}
