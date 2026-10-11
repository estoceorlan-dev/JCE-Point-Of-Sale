import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/native_auth_providers.dart';
import '../config/app_config.dart';
import '../startup/app_initialization_service.dart';
import '../sync/node_queue_recovery.dart';

final appInitializationServiceProvider = Provider<AppInitializationService>((
  ref,
) {
  return NodeInitializationService(
    initializeBinding: () => ref.read(installationBindingProvider).initialize(),
    recoverQueue: () => ref.read(nodeQueueRecoveryProvider).recover(),
    native: !kIsWeb,
  );
});

class NodeInitializationService implements AppInitializationService {
  const NodeInitializationService({
    required this.initializeBinding,
    required this.recoverQueue,
    required this.native,
  });

  final Future<void> Function() initializeBinding;
  final Future<void> Function() recoverQueue;
  final bool native;

  @override
  Future<void> initialize(AppConfig config) async {
    if (config.enableDemoAuth) return;
    await initializeBinding();
    if (native) unawaited(recoverQueue());
  }
}
