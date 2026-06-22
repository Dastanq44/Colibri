import '../../core/result/result.dart';
import '../../features/library/domain/library_book.dart';
import '../../shared/models/bookshelf_status.dart';

/// Boundary for the user's personal library ("My Books"). Local-first; cloud
/// refresh is added in a later phase.
abstract interface class LibraryRepository {
  /// One-shot read of the local library.
  Future<Result<List<LibraryBook>>> getMyBooks();

  /// Reactive view of the local library (updates as books change).
  Stream<List<LibraryBook>> watchMyBooks();

  /// Updates a book's shelf status.
  Future<Result<void>> updateBookStatus(String bookId, BookShelfStatus status);

  /// Removes all local records for the book (and its on-disk file).
  Future<Result<void>> removeBookFromLibrary(String bookId);
}
