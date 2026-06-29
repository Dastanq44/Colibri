/// Outcome of a single sync pass.
class SyncRunResult {
  const SyncRunResult({
    required this.processed,
    required this.succeeded,
    required this.failed,
  });

  final int processed;
  final int succeeded;
  final int failed;

  bool get hadFailures => failed > 0;
}
