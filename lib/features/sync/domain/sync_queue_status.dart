/// Queue-item lifecycle statuses, stored in `sync_queue.status`.
///
/// NOTE: this is the *queue item* status and is distinct from the row-level
/// `SyncStatus` (local_only / pending_upload / pending_update / synced /
/// failed / deleted) stored on entity tables. The queue tracks the unit of
/// work; the row status tracks whether an entity is in sync.
abstract final class SyncQueueStatus {
  const SyncQueueStatus._();

  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String failed = 'failed';
  static const String done = 'done';

  /// Max attempts before an item is parked as permanently [failed].
  static const int maxAttempts = 5;
}
