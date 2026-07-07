import '../../core/result/result.dart';
import '../../features/sync/domain/remote_progress.dart';
import '../../features/sync/domain/sync_result.dart';

/// Boundary for the offline-first sync engine (sync queue processing).
/// Returns a typed failure when the backend is unconfigured or the user is
/// signed out; processes runnable queue items otherwise.
abstract interface class SyncRepository {
  /// Processes runnable pending sync-queue items now. [retryFailed] gives
  /// permanently `failed` items a fresh attempt budget — pass it for
  /// user-initiated syncs only, so automatic passes skip known-bad items.
  Future<Result<SyncRunResult>> syncNow({bool retryFailed = false});

  /// Emits `true` while a sync pass is in progress.
  Stream<bool> syncing();

  /// The cloud reading position for a book, or `Ok(null)` when the cloud has
  /// none. Used by the reader to detect significant position conflicts
  /// (TASK-1203); failures are non-fatal (reading is never blocked by sync).
  Future<Result<RemoteProgress?>> fetchRemoteProgress(String bookId);
}
