enum SyncStatus { idle, syncing, offline, failed }

class SyncState {
  const SyncState({
    required this.status,
    this.lastSyncedAt,
    this.pendingChanges = 0,
    this.retryingChanges = 0,
    this.failedChanges = 0,
    this.conflicts = 0,
    this.message,
  });

  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final int pendingChanges;
  final int retryingChanges;
  final int failedChanges;
  final int conflicts;
  final String? message;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    int? pendingChanges,
    int? retryingChanges,
    int? failedChanges,
    int? conflicts,
    String? message,
    bool clearMessage = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      retryingChanges: retryingChanges ?? this.retryingChanges,
      failedChanges: failedChanges ?? this.failedChanges,
      conflicts: conflicts ?? this.conflicts,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}
