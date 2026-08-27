import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'app_database_config.dart';
import 'daos/audit_log_dao.dart';
import 'daos/metadata_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/sync_conflict_dao.dart';
import 'daos/sync_cursor_dao.dart';
import 'daos/sync_entity_version_dao.dart';

final appDatabaseConfigProvider = Provider<AppDatabaseConfig>((ref) {
  return const AppDatabaseConfig();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(ref.watch(appDatabaseConfigProvider));
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
