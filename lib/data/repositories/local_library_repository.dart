import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../core/result/result.dart';
import '../../features/import/data/file_storage_service.dart';
import '../../features/library/domain/library_book.dart';
import '../../shared/models/book_format.dart';
import '../../shared/models/bookshelf_status.dart';
import '../local/app_database.dart';
import 'library_repository.dart';

/// Local-first [LibraryRepository] backed by Drift. Joins books + bookshelf +
/// progress into [LibraryBook] views. No Supabase access here.
class LocalLibraryRepository implements LibraryRepository {
  LocalLibraryRepository(this._db, this._storage);

  final AppDatabase _db;
  final FileStorageService _storage;

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
  Future<Result<void>> updateBookStatus(String bookId, String status) async {
    try {
      await _db.bookshelfDao.setStatus(bookId, status);
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> removeBookFromLibrary(String bookId) async {
    try {
      await (_db.delete(_db.localReadingProgress)
            ..where((p) => p.bookId.equals(bookId)))
          .go();
      await (_db.delete(_db.localBookshelf)..where((e) => e.bookId.equals(bookId)))
          .go();
      await _db.booksDao.deleteById(bookId);
      await _storage.deleteBookStorage(bookId);
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }
  }
}
