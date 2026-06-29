import '../../core/result/result.dart';
import '../../features/sync/domain/sync_result.dart';

/// Boundary for the offline-first sync engine (sync queue processing). Returns
/// a typed failure when the backend is unconfigured or the user is signed out;
/// processes runnable queue items otherwise. Conflict resolution is not
/// implemented yet (last local write wins per device).
abstract interface class SyncRepository {
  /// Processes runnable pending sync-queue items now.
  Future<Result<SyncRunResult>> syncNow();

  /// Emits `true` while a sync pass is in progress.
  Stream<bool> syncing();
}
