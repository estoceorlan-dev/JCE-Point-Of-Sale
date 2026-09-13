import '../../shared/models/business_context.dart';

enum SyncTrigger { manual, signIn, reconnect, foreground, periodic, background }

class SyncRunResult {
  const SyncRunResult({
    required this.trigger,
    required this.startedAt,
    required this.finishedAt,
    required this.pushed,
    required this.pulled,
    required this.conflicts,
    required this.offline,
  });

  final SyncTrigger trigger;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int pushed;
  final int pulled;
  final int conflicts;
  final bool offline;
}

/// Coalesces every synchronization trigger for one operational scope.
abstract interface class SyncCoordinator {
  Future<SyncRunResult> synchronize({
    required BusinessContext context,
    SyncTrigger trigger = SyncTrigger.manual,
  });
}
