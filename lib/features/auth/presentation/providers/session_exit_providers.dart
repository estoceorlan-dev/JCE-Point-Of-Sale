import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/services/backend_sync_service.dart';
import '../../data/repositories/offline_first_session_exit_repository.dart';
import '../../domain/repositories/session_exit_repository.dart';

final sessionExitRepositoryProvider = Provider<SessionExitRepository>((ref) {
  return OfflineFirstSessionExitRepository(
    database: ref.watch(appDatabaseProvider),
    outboxDao: ref.watch(outboxDaoProvider),
    syncService: ref.watch(backendSyncServiceProvider),
  );
});
