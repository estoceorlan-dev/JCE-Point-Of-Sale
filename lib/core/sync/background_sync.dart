import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../shared/models/business_context.dart';
import '../config/app_config.dart';
import '../services/backend_sync_service.dart';
import '../services/firebase_initialization_service.dart';

const backgroundSyncTaskName = 'com.jce.pos.background_sync';

bool get _supportsNativeBackgroundSync =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

Future<void> initializeBackgroundSync() async {
  if (!_supportsNativeBackgroundSync) return;
  await Workmanager().initialize(syncCallbackDispatcher);
}

Future<void> scheduleBackgroundSync() async {
  if (!_supportsNativeBackgroundSync) return;
  await Workmanager().registerPeriodicTask(
    backgroundSyncTaskName,
    backgroundSyncTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 1),
  );
}

@pragma('vm:entry-point')
void syncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != backgroundSyncTaskName) return true;
    WidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer();
    try {
      final config = container.read(appConfigProvider);
      if (config.enableDemoAuth) return true;
      await container
          .read(firebaseInitializationServiceProvider)
          .initialize(config);
      final session = await container.read(authControllerProvider.future);
      if (session == null) return true;
      final result = await container
          .read(backendSyncServiceProvider)
          .synchronize(
            context: BusinessContext(
              organizationId: session.activeOrganizationId,
              branchId: session.activeBranchId,
              actorUserId: session.activeOrganization.appUserId,
            ),
            trigger: SyncTrigger.background,
          );
      return !result.offline;
    } catch (_) {
      return false;
    } finally {
      container.dispose();
    }
  });
}
