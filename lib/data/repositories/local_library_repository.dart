import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../core/result/result.dart';
import '../../features/import/data/file_storage_service.dart';
import '../../features/library/domain/library_book.dart';
import '../../features/sync/data/local_sync_queue_repository.dart';
import '../../shared/models/book_format.dart';
import '../../shared/models/bookshelf_status.dart';
import '../local/app_database.dart';
import 'library_repository.dart';

/// Local-first [LibraryRepository] backed by Drift. Joins books + bookshelf +
/// progress into [LibraryBook] views. Local changes are enqueued for later
/// cloud sync; no direct Supabase access here.
class LocalLibraryRepository implements LibraryRepository {
  LocalLibraryRepository(this._db, this._storage, this._sync);

  final AppDatabase _db;
  final FileStorageService _storage;
  final LocalSyncQueueRepository _sync;

  JoinedSelectStatement<HasResultSet, dynamic> _libraryQuery() {
    return _db.select(_db.localBooks).join(<Join>[
      leftOuterJoin(
        _db.localBookshelf,
        _db.localBookshelf.bookId.equalsExp(_db.localBooks.id),
      ),
      leftOuterJoin(
        _db.localReadingProgress,
        _db.localReadingProgress.bookId.equalsExp(_db.localBooks.id),
      ),
    ]);
  }

  LibraryBook _mapRow(TypedResult row) {
    final book = row.readTable(_db.localBooks);
    final shelf = row.readTableOrNull(_db.localBookshelf);
    final progress = row.readTableOrNull(_db.localReadingProgress);
    return LibraryBook(
      id: book.id,
      title: book.title,
      authorDisplay: book.authorDisplay,
      format: BookFormat.fromWire(book.format),
      status: BookShelfStatus.fromWire(shelf?.status ?? BookShelfStatus.reading.wire),
      percent: progress?.percent ?? 0,
      isFastModeSupported: book.isFastModeSupported,
      lastOpenedAt: book.lastOpenedAt == null
          ? null
          : DateTime.tryParse(book.lastOpenedAt!),
    );
  }

  @override
  Stream<List<LibraryBook>> watchMyBooks() =>
      _libraryQuery().watch().map((rows) => rows.map(_mapRow).toList());

  @override
  Future<Result<List<LibraryBook>>> getMyBooks() async {
    try {
      final rows = await _libraryQuery().get();
      return Ok(rows.map(_mapRow).toList());
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> updateBookStatus(
    String bookId,
    BookShelfStatus status,
  ) async {
    try {
      await _db.bookshelfDao.setStatus(bookId, status.wire);
      await _sync.enqueueBookshelf(bookId);
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> removeBookFromLibrary(String bookId) async {
    // Local-only delete for now: clears local records + queued sync ops so a
    // removed book is not later uploaded.
    // TODO(sync): if the book was already synced (cloudBookId set), enqueue a
    // cloud delete and define multi-device delete semantics.
    try {
      await _db.transaction(() async {
        await (_db.delete(_db.localReadingProgress)
              ..where((p) => p.bookId.equals(bookId)))
            .go();
        await (_db.delete(_db.localBookshelf)
              ..where((e) => e.bookId.equals(bookId)))
            .go();
        await (_db.delete(_db.localReadingSessions)
              ..where((s) => s.bookId.equals(bookId)))
            .go();
        await (_db.delete(_db.localNotes)..where((n) => n.bookId.equals(bookId)))
            .go();
        await (_db.delete(_db.localBookmarks)
              ..where((b) => b.bookId.equals(bookId)))
            .go();
        // Drop any queued sync ops that reference this book.
        await (_db.delete(_db.syncQueue)
              ..where((q) => q.entityId.equals(bookId)))
            .go();
        await _db.booksDao.deleteById(bookId);
      });
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }

    // 2) Best-effort file cleanup after the DB is consistent. A failure here
    //    leaves only an orphaned file (records are already gone) — surface it
    //    as a typed failure but do not crash.
    try {
      await _storage.deleteBookStorage(bookId);
    } catch (e) {
      return Err(StorageFailure('Removed records, but file cleanup failed: $e'));
    }
    return const Ok(null);
  }
}
