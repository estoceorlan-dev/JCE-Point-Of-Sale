import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import '../config/app_config.dart';
import '../config/node_installation_profile.dart';
import '../../features/auth/presentation/providers/native_auth_providers.dart';
import 'app_database_config.dart';
import 'daos/audit_log_dao.dart';
import 'daos/metadata_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/sync_conflict_dao.dart';
import 'daos/sync_cursor_dao.dart';
import 'daos/sync_entity_version_dao.dart';

final appDatabaseConfigProvider = Provider<AppDatabaseConfig>((ref) {
  if (ref.watch(appConfigProvider).useNodeBackend) {
    return AppDatabaseConfig(
      name: deploymentDatabaseName(
        ref.watch(nativeAuthProfileProvider).deploymentId,
      ),
    );
  }
  return const AppDatabaseConfig();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(ref.watch(appDatabaseConfigProvider));
  if (ref.watch(appConfigProvider).useNodeBackend) {
    database.signOutboxCommand = ref.watch(nodeActorEvidenceProvider).sign;
  }
  ref.onDispose(database.close);
  return database;
});

final metadataDaoProvider = Provider<MetadataDao>((ref) {
  return ref.watch(appDatabaseProvider).metadataDao;
});

final outboxDaoProvider = Provider<OutboxDao>((ref) {
  return ref.watch(appDatabaseProvider).outboxDao;
});

final syncCursorDaoProvider = Provider<SyncCursorDao>((ref) {
  return ref.watch(appDatabaseProvider).syncCursorDao;
});

final syncConflictDaoProvider = Provider<SyncConflictDao>((ref) {
  return ref.watch(appDatabaseProvider).syncConflictDao;
});

final syncEntityVersionDaoProvider = Provider<SyncEntityVersionDao>((ref) {
  return ref.watch(appDatabaseProvider).syncEntityVersionDao;
});

final auditLogDaoProvider = Provider<AuditLogDao>((ref) {
  return ref.watch(appDatabaseProvider).auditLogDao;
});

final pendingOutboxCountProvider = StreamProvider<int>((ref) {
  return ref.watch(outboxDaoProvider).watchPendingCount();
});
