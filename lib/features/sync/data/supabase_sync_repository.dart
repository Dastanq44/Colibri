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
  Future<Result<SyncRunResult>> syncNow() async {
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
      final items = await _db.syncQueueDao.getRunnablePending(limit: 50);
      for (final item in items) {
        processed++;
        await _db.syncQueueDao.markProcessing(item.id);
        try {
          await _processItem(client, userId, item);
          await _db.syncQueueDao.markDone(item.id);
          succeeded++;
        } catch (_) {
          // No private content is logged.
          await _db.syncQueueDao
              .markFailed(item.id, retryAfter: _backoff(item.attemptCount));
          failed++;
        }
      }
      return Ok(SyncRunResult(
        processed: processed,
        succeeded: succeeded,
        failed: failed,
      ));
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
    final bookUuid = localBookIdToUuid(item.entityId);

    switch (type!) {
      case SyncEntityType.book:
        await client.from('books').upsert(booksRow(bookUuid, payload));
      case SyncEntityType.bookshelf:
        await client.from('user_bookshelf').upsert(
              bookshelfRow(userId, bookUuid, payload),
              onConflict: 'user_id,book_id',
            );
      case SyncEntityType.readingProgress:
        await client.from('reading_progress').upsert(
              progressRow(userId, bookUuid, payload),
              onConflict: 'user_id,book_id',
            );
      case SyncEntityType.bookFile:
        await _uploadBookFile(client, userId, bookUuid, payload);
      case SyncEntityType.readerSettings:
      case SyncEntityType.fastSettings:
      case SyncEntityType.note:
      case SyncEntityType.bookmark:
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
