import 'node_queue_recovery.dart';
import '../../features/auth/presentation/providers/native_auth_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../config/app_config.dart';

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
      await container.read(installationBindingProvider).initialize();
      await container.read(nodeQueueRecoveryProvider).recover();
      return true;
    } catch (_) {
      return false;
    } finally {
      container.dispose();
    }
  });
}
