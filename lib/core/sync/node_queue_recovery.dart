import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/native_auth_providers.dart';
import '../../shared/models/business_context.dart';
import '../database/database_provider.dart';
import '../error/failures.dart';
import '../logger/app_logger.dart';
import '../remote/node_sync_data_source.dart';
import '../remote/remote_sync_data_source.dart';
import '../services/backend_sync_service.dart';
import '../utils/app_clock.dart';
import 'connectivity_monitor.dart';

/// Device-only recovery never restores a cashier or rotates their session tokens.
final nodeQueueRecoveryProvider = Provider<NodeQueueRecovery>((ref) {
  return NodeQueueRecovery(ref);
});

class NodeQueueRecovery {
  const NodeQueueRecovery(this.ref);
  final Ref ref;
  Future<void> recover() async {
    try {
      final scope = await ref
          .read(nativeCredentialRecordsProvider)
          .transact((state) async => state['deviceScope'] as Map?);
      if (scope == null) return;
      final service = OfflineFirstBackendSyncService(
        deviceUploads: true,
        commands: ref.read(remoteCommandDataSourceProvider),
        remote: _DeviceOnlyReads(ref.read(nodeDeviceTransportProvider)),
        database: ref.read(appDatabaseProvider),
        outboxDao: ref.read(outboxDaoProvider),
        cursorDao: ref.read(syncCursorDaoProvider),
        conflictDao: ref.read(syncConflictDaoProvider),
        versionDao: ref.read(syncEntityVersionDaoProvider),
        applier: ref.read(remoteChangeApplierProvider),
        connectivity: ref.read(connectivityMonitorProvider),
        clock: ref.read(appClockProvider),
        logger: ref.read(appLoggerProvider),
      );
      await service.synchronize(
        context: BusinessContext(
          organizationId: scope['organizationId'] as String,
          branchId: scope['branchId'] as String,
          actorUserId: '',
        ),
        trigger: SyncTrigger.background,
      );
    } catch (error, stack) {
      ref
          .read(appLoggerProvider)
          .warning(
            'Device queue recovery will retry; local records remain saved.',
            scope: 'sync.recovery',
            error: error,
            stackTrace: stack,
          );
    }
  }
}

class _DeviceOnlyReads extends NodeSyncDataSource {
  const _DeviceOnlyReads(super.transport);
  @override
  Future<RemoteChangePage> pullChangePage({
    required String organizationId,
    required String branchId,
    required int afterSequence,
    int limit = 100,
  }) async => throw const AuthenticationFailure(
    'Device-only upload does not restore a cashier.',
    code: 'unauthorized',
  );
}
