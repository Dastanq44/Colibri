import 'dart:convert';

import '../../../data/local/app_database.dart';
import '../domain/sync_entity_type.dart';
import '../domain/sync_operation.dart';

/// Wraps [SyncQueueDao]: builds snapshot payloads from local rows and enqueues
/// (coalesced) sync work. UI/repositories call these instead of touching the
/// DAO directly.
class LocalSyncQueueRepository {
  LocalSyncQueueRepository(this._db, {String? Function()? currentUserId})
      : _currentUserId = currentUserId ?? _signedOut;

  final AppDatabase _db;

  /// Resolves the signed-in user's id at enqueue time. Must return null when
  /// signed out or when no backend is configured (and never throw). Rows
  /// enqueued with a null user attach to the first account that syncs them.
  final String? Function() _currentUserId;

  static String? _signedOut() => null;

  Future<void> enqueueBookCreate(String bookId) async {
    final book = await _db.booksDao.getById(bookId);
    if (book == null) return;
    await _enqueue(
      SyncEntityType.book,
      bookId,
      SyncOperation.create,
      <String, dynamic>{
        'format': book.format,
        'title': book.title,
        'language': book.language,
        'is_fast_mode_supported': book.isFastModeSupported,
        'text_ready_status': book.textReadyStatus,
      },
    );
  }

  Future<void> enqueueBookFileUpload(String bookId) async {
    final book = await _db.booksDao.getById(bookId);
    if (book == null) return;
    await _enqueue(
      SyncEntityType.bookFile,
      bookId,
      SyncOperation.uploadFile,
      <String, dynamic>{
        'file_local_path': book.fileLocalPath,
        'checksum_sha256': book.checksumSha256,
        'format': book.format,
      },
    );
  }

  Future<void> enqueueBookshelf(
    String bookId, {
    SyncOperation operation = SyncOperation.update,
  }) async {
    final shelf = await _db.bookshelfDao.getByBookId(bookId);
    if (shelf == null) return;
    await _enqueue(
      SyncEntityType.bookshelf,
      bookId,
      operation,
      <String, dynamic>{
        'status': shelf.status,
        'started_at': shelf.startedAt,
        'finished_at': shelf.finishedAt,
        'added_at': shelf.addedAt,
        'last_opened_at': shelf.lastOpenedAt,
      },
    );
  }

  Future<void> enqueueProgressUpdate(String bookId) async {
    final p = await _db.progressDao.getByBookId(bookId);
    if (p == null) return;
    await _enqueue(
      SyncEntityType.readingProgress,
      bookId,
      SyncOperation.update,
      <String, dynamic>{
        'locator_type': p.locatorType,
        'locator_value': p.locatorValue,
        'chapter_index': p.chapterIndex,
        'page_number': p.pageNumber,
        'paragraph_index': p.paragraphIndex,
        'token_index': p.tokenIndex,
        'percent': p.percent,
        'mode': p.mode,
        'device_id': p.deviceId,
        'revision': p.revision,
        'updated_at': p.updatedAt,
      },
    );
  }

  Future<int> pendingCount() =>
      _db.syncQueueDao.pendingCount(userId: _currentUserId());

  /// Live count of this user's not-yet-synced changes (including unstamped
  /// rows enqueued while signed out).
  Stream<int> watchPendingCount() =>
      _db.syncQueueDao.watchPendingCount(userId: _currentUserId());

  Future<void> _enqueue(
    SyncEntityType type,
    String entityId,
    SyncOperation op,
    Map<String, dynamic> payload,
  ) {
    return _db.syncQueueDao.enqueueOrReplace(
      entityType: type.wire,
      entityId: entityId,
      operation: op.wire,
      payloadJson: jsonEncode(payload),
      userId: _currentUserId(),
    );
  }
}
