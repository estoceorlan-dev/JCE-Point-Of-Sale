import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../shared/models/business_context.dart';
import '../../shared/models/permission.dart';
import '../../shared/models/sync_state.dart';
import '../config/app_config.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../database/models/sync_diagnostics.dart';
import '../error/result.dart';
import '../error/failure.dart';
import '../error/failure_mapper.dart';
import '../services/backend_sync_service.dart';
import '../services/administration_snapshot_service.dart';
import '../services/stock_location_snapshot_service.dart';
import 'connectivity_monitor.dart';
import 'background_sync.dart';

final syncStateProvider =
    StateNotifierProvider<SyncController, AsyncValue<SyncState>>((ref) {
      final session = ref.watch(authControllerProvider).asData?.value;
      final context = session == null
          ? null
          : BusinessContext(
              organizationId: session.activeOrganizationId,
              branchId: session.activeBranchId,
              actorUserId: session.activeOrganization.appUserId,
            );
      return SyncController(
        ref,
        context,
        automatic: !ref.watch(appConfigProvider).enableDemoAuth,
        hydrateAdministration:
            session?.administrationPermissions.isNotEmpty ?? false,
        hydrateLocations: session?.can(AppPermission.manageInventory) ?? false,
      );
    });

final unresolvedSyncConflictsProvider = StreamProvider<List<SyncConflict>>((
  ref,
) {
  final session = ref.watch(authControllerProvider).asData?.value;
  if (session == null) return Stream.value(const []);
  return ref
      .watch(syncConflictDaoProvider)
      .watchUnresolvedFor(
        organizationId: session.activeOrganizationId,
        branchId: session.activeBranchId,
      );
});

class SyncController extends StateNotifier<AsyncValue<SyncState>> {
  SyncController(
    this._ref,
    this._context, {
    required bool automatic,
    required bool hydrateAdministration,
    bool hydrateLocations = false,
  }) : _hydrateAdministration = hydrateAdministration,
       _hydrateLocations = hydrateLocations,
       super(const AsyncData(SyncState(status: SyncStatus.idle))) {
    if (_context == null) {
      _legacyPendingSubscription = _ref
          .read(outboxDaoProvider)
          .watchPendingCount()
          .listen((pending) {
            final current =
                state.asData?.value ?? const SyncState(status: SyncStatus.idle);
            state = AsyncData(current.copyWith(pendingChanges: pending));
          });
      return;
    }
    _diagnosticsSubscription = _ref
        .read(outboxDaoProvider)
        .watchDiagnostics(
          organizationId: _context.organizationId,
          branchId: _context.branchId,
          actorUserId: _context.actorUserId,
        )
        .listen(_applyDiagnostics);
    _conflictSubscription = _ref
        .read(syncConflictDaoProvider)
        .watchUnresolvedFor(
          organizationId: _context.organizationId,
          branchId: _context.branchId,
        )
        .listen((rows) {
          final current =
              state.asData?.value ?? const SyncState(status: SyncStatus.idle);
          state = AsyncData(current.copyWith(conflicts: rows.length));
        });
    if (!automatic) return;
    unawaited(scheduleBackgroundSync());
    _connectivitySubscription = _ref
        .read(connectivityMonitorProvider)
        .changes
        .listen((connected) {
          if (connected) {
            unawaited(synchronize(SyncTrigger.reconnect));
          } else {
            final current =
                state.asData?.value ?? const SyncState(status: SyncStatus.idle);
            state = AsyncData(
              current.copyWith(
                status: SyncStatus.offline,
                message: 'Network unavailable. Local changes are safe.',
              ),
            );
          }
        });
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(synchronize(SyncTrigger.periodic)),
    );
    Future<void>.microtask(() => synchronize(SyncTrigger.signIn));
  }

  final Ref _ref;
  final BusinessContext? _context;
  final bool _hydrateAdministration;
  final bool _hydrateLocations;
  StreamSubscription<SyncDiagnostics>? _diagnosticsSubscription;
  StreamSubscription<int>? _legacyPendingSubscription;
  StreamSubscription<List<SyncConflict>>? _conflictSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _periodicTimer;

  Future<void> synchronize([SyncTrigger trigger = SyncTrigger.manual]) async {
    final context = _context;
    if (context == null || state.asData?.value.status == SyncStatus.syncing) {
      return;
    }
    final current =
        state.asData?.value ?? const SyncState(status: SyncStatus.idle);
    state = AsyncData(
      current.copyWith(
        status: SyncStatus.syncing,
        message: 'Synchronizing local and remote data…',
      ),
    );
    try {
      if (_hydrateAdministration &&
          await _ref.read(connectivityMonitorProvider).isConnected) {
        await _ref
            .read(administrationSnapshotServiceProvider)
            .hydrateIfNeeded(
              context,
              scopeKey:
                  _ref
                      .read(authControllerProvider)
                      .asData
                      ?.value
                      ?.administrationScopeKey ??
                  '',
            );
      }
      final result = await _ref
          .read(backendSyncServiceProvider)
          .synchronize(context: context, trigger: trigger);
      final latest = state.asData?.value ?? current;
      if (_hydrateLocations && !result.offline) {
        await _ref.read(stockLocationSnapshotServiceProvider).refresh(context);
      }
      state = AsyncData(
        latest.copyWith(
          status: result.offline ? SyncStatus.offline : SyncStatus.idle,
          lastSyncedAt: result.offline ? null : result.finishedAt,
          message: result.offline
              ? 'Network unavailable. Local changes are safe.'
              : 'Synced ${result.pushed} uploads and ${result.pulled} updates.',
        ),
      );
    } catch (error, stackTrace) {
      final latest = state.asData?.value ?? current;
      state = AsyncError(error, stackTrace);
      state = AsyncData(
        latest.copyWith(
          status: SyncStatus.failed,
          message: 'Sync could not reach or apply the backend. Retry is safe.',
        ),
      );
    }
  }

  Future<void> retryConflict(SyncConflict conflict) async {
    final now = DateTime.now().toUtc();
    await _ref.read(appDatabaseProvider).transaction(() async {
      await _ref.read(outboxDaoProvider).retry(conflict.operationId, now);
      await _ref
          .read(syncConflictDaoProvider)
          .resolve(
            id: conflict.id,
            resolutionStatus: 'retry_local',
            resolvedAt: now,
          );
    });
    await synchronize(SyncTrigger.manual);
  }

  Future<Result<void, Failure>> acceptRemote(SyncConflict conflict) async {
    try {
      await _acceptRemote(conflict);
      return const Result.success(null);
    } catch (error, stackTrace) {
      return Result.failure(FailureMapper.fromException(error, stackTrace));
    }
  }

  Future<void> _acceptRemote(SyncConflict conflict) async {
    if (conflict.entityType == 'stock_location') {
      final context = _context;
      if (context == null || !_hydrateLocations) {
        throw StateError('Inventory management access is required.');
      }
      await _ref
          .read(stockLocationSnapshotServiceProvider)
          .acceptRemote(context, conflict);
      await synchronize(SyncTrigger.manual);
      return;
    }
    if (const {
      'branch',
      'app_user',
      'role',
      'register',
      'tax_category',
    }.contains(conflict.entityType)) {
      final context = _context;
      if (context == null || !_hydrateAdministration) {
        throw StateError(
          'Organization-wide administration access is required.',
        );
      }
      await _ref
          .read(administrationSnapshotServiceProvider)
          .acceptRemote(context, conflict);
      await synchronize(SyncTrigger.manual);
      return;
    }
    final now = DateTime.now().toUtc();
    await _ref.read(appDatabaseProvider).transaction(() async {
      await _ref.read(outboxDaoProvider).discard(conflict.operationId, now);
      await _ref
          .read(syncConflictDaoProvider)
          .resolve(
            id: conflict.id,
            resolutionStatus: 'accepted_remote',
            resolvedAt: now,
          );
    });
    await synchronize(SyncTrigger.manual);
  }

  void onForeground() {
    unawaited(synchronize(SyncTrigger.foreground));
  }

  void _applyDiagnostics(SyncDiagnostics diagnostics) {
    final current =
        state.asData?.value ?? const SyncState(status: SyncStatus.idle);
    state = AsyncData(
      current.copyWith(
        pendingChanges: diagnostics.pending + diagnostics.processing,
        retryingChanges: diagnostics.retrying,
        failedChanges: diagnostics.failed,
        conflicts: diagnostics.conflicted,
      ),
    );
  }

  @override
  void dispose() {
    _diagnosticsSubscription?.cancel();
    _legacyPendingSubscription?.cancel();
    _conflictSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }
}
