import '../../core/result/result.dart';
import '../../features/library/domain/library_book.dart';

/// Boundary for the user's personal library ("My Books"). Local-first; cloud
/// refresh is added in a later phase.
abstract interface class LibraryRepository {
  /// One-shot read of the local library.
  Future<Result<List<LibraryBook>>> getMyBooks();

  /// Reactive view of the local library (updates as books change).
  Stream<List<LibraryBook>> watchMyBooks();

  /// [status] is one of: reading | finished | abandoned | want_to_read.
  Future<Result<void>> updateBookStatus(String bookId, String status);

  /// Removes the local book record (and its on-disk file).
  Future<Result<void>> removeBookFromLibrary(String bookId);
}
