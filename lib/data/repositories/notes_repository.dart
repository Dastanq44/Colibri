import '../../core/result/result.dart';
import '../../features/notes/domain/annotations.dart';
import '../../features/reader/domain/reader_locator.dart';

/// Boundary for notes and bookmarks (Phase 11). Offline-first: writes land in
/// the local database with soft deletes and are queued for cloud sync.
abstract interface class NotesRepository {
  Future<Result<Bookmark>> createBookmark(
    String bookId, {
    required ReaderLocator locator,
    String? label,
  });

  Future<Result<Note>> createNote(
    String bookId, {
    required ReaderLocator locator,
    required String noteText,
    String? selectedText,
  });

  /// Live non-deleted bookmarks for a book, newest first.
  Stream<List<Bookmark>> watchBookmarks(String bookId);

  /// Live non-deleted notes for a book, newest first.
  Stream<List<Note>> watchNotes(String bookId);

  Future<Result<void>> deleteBookmark(String id);

  Future<Result<void>> deleteNote(String id);
}
