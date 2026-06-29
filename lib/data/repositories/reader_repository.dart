import '../../core/result/result.dart';
import '../../features/reader/domain/reader_document.dart';
import '../../features/reader/domain/reader_locator.dart';
import '../../features/reader/domain/reader_mode.dart';

/// Boundary for loading readable book content and persisting reading position.
/// The reader engine/UI goes through this — never the file system or Drift.
abstract interface class ReaderRepository {
  /// Loads a book into a format-agnostic [ReaderDocument]. Returns a typed
  /// failure for unsupported formats or missing files. Also stamps the book's
  /// `lastOpenedAt`.
  Future<Result<ReaderDocument>> openBook(String bookId);

  /// The last saved position for a book, or `null` if none.
  Future<Result<ReaderLocator?>> getSavedLocator(String bookId);

  /// Persists the current reading position locally, tagged with the [mode] it
  /// was produced in (normal or fast).
  Future<Result<void>> saveLocator(
    String bookId,
    ReaderLocator locator, {
    ReaderMode mode = ReaderMode.normal,
  });
}
