import '../../core/result/result.dart';

/// Boundary for the user's personal library ("My Books"). Implemented in
/// Phase 5 (local-first, with cloud refresh).
abstract interface class LibraryRepository {
  Future<Result<void>> getMyBooks();

  Future<Result<void>> addBookToLibrary(String bookId);

  /// [status] is one of: reading | finished | abandoned | want_to_read.
  Future<Result<void>> updateBookStatus(String bookId, String status);

  Future<Result<void>> removeBookFromLibrary(String bookId);

  Future<Result<void>> getContinueReading();
}
