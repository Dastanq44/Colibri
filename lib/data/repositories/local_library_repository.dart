import 'dart:io';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/errors/failures.dart';
import '../../core/result/result.dart';
import '../../features/catalog/domain/catalog_book.dart';
import '../../features/import/data/file_storage_service.dart';
import '../../features/library/domain/library_book.dart';
import '../../features/reader/data/epub_extractor.dart';
import '../../features/sync/data/local_sync_queue_repository.dart';
import '../../shared/models/book_format.dart';
import '../../shared/models/bookshelf_status.dart';
import '../local/app_database.dart';
import '../local/sync_status.dart';
import 'library_repository.dart';

/// Local-first [LibraryRepository] backed by Drift. Joins books + bookshelf +
/// progress into [LibraryBook] views. Local changes are enqueued for later
/// cloud sync; [refreshFromCloud] pulls missing cloud-shelf entries.
class LocalLibraryRepository implements LibraryRepository {
  LocalLibraryRepository(this._db, this._storage, this._sync,
      {SupabaseClient? client})
      : _client = client;

  final AppDatabase _db;
  final FileStorageService _storage;
  final LocalSyncQueueRepository _sync;
  final SupabaseClient? _client;

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
      hasLocalFile: book.fileLocalPath.isNotEmpty,
      cloudBookId: book.cloudBookId,
      coverPath: book.coverLocalPath,
      language: book.language,
      isFavorite: shelf?.isFavorite ?? false,
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
  Future<Result<void>> setFavorite(String bookId, bool favorite) async {
    try {
      await _db.bookshelfDao.setFavorite(bookId, favorite);
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }
  }

  @override
  Future<int> backfillCovers() async {
    var added = 0;
    try {
      const extractor = EpubExtractor();
      final books = await _db.booksDao.getAll();
      for (final book in books) {
        if (book.coverLocalPath != null ||
            book.format != BookFormat.epub.wire ||
            book.fileLocalPath.isEmpty) {
          continue;
        }
        try {
          final file = File(book.fileLocalPath);
          if (!await file.exists()) continue;
          final cover = extractor.extractCover(await file.readAsBytes());
          if (cover == null) continue;
          final path = await _storage.saveCoverBytes(
            bookId: book.id,
            bytes: cover.bytes,
            extension: cover.extension,
          );
          await _db.booksDao.upsertBook(LocalBooksCompanion(
            id: Value(book.id),
            coverLocalPath: Value(path),
          ));
          added++;
        } catch (_) {
          // Cosmetic; skip this book and keep going.
        }
      }
    } catch (_) {
      // Best-effort sweep — never surface an error for covers.
    }
    return added;
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
        // Annotation queue rows are keyed by the annotation's own id, so
        // collect them before the rows go away — otherwise their queued
        // snapshots would still upload after the book is removed.
        final noteIds = await (_db.select(_db.localNotes)
              ..where((n) => n.bookId.equals(bookId)))
            .map((n) => n.id)
            .get();
        final bookmarkIds = await (_db.select(_db.localBookmarks)
              ..where((b) => b.bookId.equals(bookId)))
            .map((b) => b.id)
            .get();
        await (_db.delete(_db.localNotes)..where((n) => n.bookId.equals(bookId)))
            .go();
        await (_db.delete(_db.localBookmarks)
              ..where((b) => b.bookId.equals(bookId)))
            .go();
        // Drop any queued sync ops that reference this book or its
        // annotations.
        final removedIds = <String>[bookId, ...noteIds, ...bookmarkIds];
        await (_db.delete(_db.syncQueue)
              ..where((q) => q.entityId.isIn(removedIds)))
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

  @override
  Future<Result<int>> refreshFromCloud() async {
    final client = _client;
    if (client == null) return const Err(BackendUnavailableFailure());
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return const Err(UnauthorizedFailure('Sign in to refresh.'));
    }
    try {
      final rows = await client
          .from('user_bookshelf')
          .select('book_id, status, '
              'books(id, title, subtitle, description, language, format, '
              'cover_url, is_fast_mode_supported, book_authors(authors(name)))')
          .eq('user_id', userId);

      var added = 0;
      for (final row in rows) {
        final bookRow = (row['books'] as Map?)?.cast<String, dynamic>();
        final cloudId = row['book_id'] as String?;
        if (bookRow == null || cloudId == null) continue;

        // Cloud uuids reverse to our 32-hex local ids, so books uploaded
        // from this device map back to their existing local rows.
        final localId = cloudId.replaceAll('-', '');
        if (await _db.bookshelfDao.getByBookId(localId) != null) {
          continue; // local-first: never overwrite an existing entry
        }

        if (await _db.booksDao.getById(localId) == null) {
          final book = CatalogBook.fromRow(bookRow);
          await _db.booksDao.upsertBook(LocalBooksCompanion.insert(
            id: localId,
            cloudBookId: Value(cloudId),
            sourceType: 'catalog',
            format: book.format,
            title: book.title,
            authorDisplay: Value(book.authorDisplay),
            language: Value(book.language ?? ''),
            // No downloaded file: the entry opens Book Detail, not the
            // reader (catalog file delivery is post-MVP).
            fileLocalPath: '',
            isFastModeSupported: Value(book.isFastModeSupported),
            syncStatus: const Value(SyncStatus.synced),
          ));
        }
        await _db.bookshelfDao.upsertEntry(LocalBookshelfCompanion.insert(
          bookId: localId,
          status: (row['status'] as String?) ?? BookShelfStatus.wantToRead.wire,
          syncStatus: const Value(SyncStatus.synced),
        ));
        added++;
      }
      return Ok(added);
    } catch (e) {
      return Err(NetworkFailure('Could not refresh the library: $e'));
    }
  }
}
