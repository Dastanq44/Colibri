import '../../core/result/result.dart';

/// Boundary for notes and bookmarks. Implemented in Phase 11 (offline-first
/// with soft deletes and sync).
abstract interface class NotesRepository {
  Future<Result<void>> createNote(String bookId, String text);

  Future<Result<void>> createBookmark(String bookId, {String? label});

  Future<Result<void>> listForBook(String bookId);

  Future<Result<void>> softDelete(String id);
}
