import '../../core/result/result.dart';

/// Boundary for the offline-first sync engine (sync queue processing,
/// progress reconciliation, conflict detection). Implemented in Phase 12.
abstract interface class SyncRepository {
  /// Processes pending sync-queue operations now.
  Future<Result<void>> syncNow();

  /// Emits `true` while a sync pass is in progress.
  Stream<bool> syncing();
}
