class SyncDiagnostics {
  const SyncDiagnostics({
    this.pending = 0,
    this.processing = 0,
    this.retrying = 0,
    this.failed = 0,
    this.conflicted = 0,
  });

  final int pending;
  final int processing;
  final int retrying;
  final int failed;
  final int conflicted;

  int get unsynchronized =>
      pending + processing + retrying + failed + conflicted;
}
