import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/sync_repository.dart';
import '../domain/sync_entity_type.dart';
import '../domain/sync_operation.dart';
import '../domain/sync_result.dart';
import 'sync_error_classifier.dart';
import 'sync_payloads.dart';

/// Processes the local sync queue against Supabase. Dev-safe: returns a typed
/// failure (and leaves the queue untouched) when no backend is configured or
/// the user is signed out. Uses the anon key + RLS only.
class SupabaseSyncRepository implements SyncRepository {
  SupabaseSyncRepository({
    required SupabaseClient? client,
    required AppDatabase db,
  })  : _client = client,
        _db = db;

  final SupabaseClient? _client;
  final AppDatabase _db;

  final StreamController<bool> _syncing = StreamController<bool>.broadcast();

  @override
  Stream<bool> syncing() => _syncing.stream;

  @override
  Future<Result<SyncRunResult>> syncNow({bool retryFailed = false}) async {
    final client = _client;
    if (client == null) return const Err(BackendUnavailableFailure());
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return const Err(UnauthorizedFailure('Sign in to sync.'));
    }

    _setSyncing(true);
    var processed = 0;
    var succeeded = 0;
    var failed = 0;
    try {
      // Exactly one in-process sync pass runs at a time (SyncController's
      // SyncRunning state rejects re-entry), so any `processing` row seen
      // here was stranded by a previous run that died mid-flight. Requeue
      // them so one-shot operations (book create, file upload) are not lost.
      await _db.syncQueueDao.requeueProcessing();

      // A user-initiated pass gives permanently `failed` items a fresh
      // attempt budget; automatic passes keep skipping them.
      if (retryFailed) {
        await _db.syncQueueDao.requeueFailed(userId: userId);
      }

      // Atomic claim: rows flip to `processing` in the same transaction that
      // selects them, so a save arriving mid-flight inserts a fresh pending
      // row instead of mutating one we already snapshotted — markDone can no
      // longer discard newer data. Only this user's rows (or unstamped ones)
      // are picked up.
      final items = await _db.syncQueueDao
          .claimRunnablePending(userId: userId, limit: 50);
      for (final item in items) {
        processed++;
        try {
          await _processItem(client, userId, item);
          // Stamping on success (not at claim) is what binds signed-out rows
          // to the account that actually synced them.
          await _db.syncQueueDao.markDone(item.id, userId: userId);
          succeeded++;
        } catch (e) {
          // No private content is logged.
          if (isTransientSyncError(e)) {
            // Offline/backend hiccup: retry later without consuming the
            // permanent-failure attempt budget.
            await _db.syncQueueDao.markRetryLater(
              item.id,
              retryAfter: _backoff(item.attemptCount),
            );
          } else {
            await _db.syncQueueDao.markFailed(
              item.id,
              retryAfter: _backoff(item.attemptCount),
            );
          }
          failed++;
        }
      }

      // Housekeeping: completed rows are kept for a week (debugging aid),
      // then pruned so the queue table cannot grow without bound.
      await _db.syncQueueDao.deleteDoneOlderThan(const Duration(days: 7));

      return Ok(SyncRunResult(
        processed: processed,
        succeeded: succeeded,
        failed: failed,
      ));
    } catch (_) {
      // Preserve the Result contract: unexpected errors (queue DB failures,
      // bugs) become a typed failure instead of escaping to the caller.
      return const Err(UnknownFailure('Sync failed.'));
    } finally {
      _setSyncing(false);
    }
  }

  Future<void> _processItem(
    SupabaseClient client,
    String userId,
    SyncQueueItem item,
  ) async {
    final type = SyncEntityType.fromWire(item.entityType);
    final op = SyncOperation.fromWire(item.operation);
    if (!isSupportedSyncItem(type, op)) {
      throw UnsupportedError('Unsupported sync item: ${item.entityType}');
    }
    final payload =
        (jsonDecode(item.payloadJson) as Map).cast<String, dynamic>();
    // For book-scoped entities this is the book id; for notes/bookmarks it is
    // the annotation's own id (their book_id travels in the payload).
    final entityUuid = localBookIdToUuid(item.entityId);

    switch (type!) {
      case SyncEntityType.book:
        await client.from('books').upsert(booksRow(entityUuid, payload));
      case SyncEntityType.bookshelf:
        await client.from('user_bookshelf').upsert(
              bookshelfRow(userId, entityUuid, payload),
              onConflict: 'user_id,book_id',
            );
      case SyncEntityType.readingProgress:
        await client.from('reading_progress').upsert(
              progressRow(userId, entityUuid, payload),
              onConflict: 'user_id,book_id',
            );
      case SyncEntityType.bookFile:
        await _uploadBookFile(client, userId, entityUuid, payload);
      case SyncEntityType.note:
        await client.from('notes').upsert(noteRow(userId, entityUuid, payload));
      case SyncEntityType.bookmark:
        await client
            .from('bookmarks')
            .upsert(bookmarkRow(userId, entityUuid, payload));
      case SyncEntityType.readerSettings:
      case SyncEntityType.fastSettings:
      case SyncEntityType.readingSession:
        throw UnsupportedError('Unsupported sync item: ${item.entityType}');
    }
  }

  Future<void> _uploadBookFile(
    SupabaseClient client,
    String userId,
    String bookUuid,
    Map<String, dynamic> payload,
  ) async {
    final path = payload['file_local_path'] as String?;
    if (path == null) throw StateError('Missing file path');
    final file = File(path);
    if (!await file.exists()) throw StateError('File missing');

    final format = (payload['format'] as String?) ?? 'txt';
    final mime = mimeForFormat(format);
    // Object name lives INSIDE the bucket and starts with the user id; the
    // bucket name is selected separately and is not part of the path.
    final objectPath = '$userId/$bookUuid/${safeStorageName(path)}';
    final bytes = await file.readAsBytes();

    await client.storage.from('book-files-private').uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: mime),
        );

    // id = bookUuid keeps one file row per book and makes the upsert idempotent.
    await client.from('book_files').upsert(<String, dynamic>{
      'id': bookUuid,
      ...bookFileRow(
        userId: userId,
        bookUuid: bookUuid,
        storagePath: objectPath,
        checksum: payload['checksum_sha256'] as String?,
        mimeType: mime,
        sizeBytes: bytes.length,
      ),
    });
    // TODO(sync): also record an `uploads` row for ingest tracking.
  }

  Duration _backoff(int attempts) =>
      Duration(seconds: (1 << attempts).clamp(1, 3600));

  void _setSyncing(bool value) {
    if (!_syncing.isClosed) _syncing.add(value);
  }

  void dispose() {
    _syncing.close();
  }
}
