import 'package:drift/drift.dart' show Value;

import '../../core/errors/failures.dart';
import '../../core/result/result.dart';
import '../../core/utils/id_generator.dart';
import '../../features/notes/domain/annotations.dart';
import '../../features/reader/domain/reader_locator.dart';
import '../../features/sync/data/local_sync_queue_repository.dart';
import '../local/app_database.dart';
import '../local/sync_status.dart';
import 'notes_repository.dart';

/// Local-first [NotesRepository]: writes go to Drift with soft deletes, and
/// every change enqueues a cloud sync snapshot (TASK-1104).
class LocalNotesRepository implements NotesRepository {
  LocalNotesRepository({
    required AppDatabase db,
    required LocalSyncQueueRepository syncQueue,
  })  : _db = db,
        _sync = syncQueue;

  final AppDatabase _db;
  final LocalSyncQueueRepository _sync;

  @override
  Future<Result<Bookmark>> createBookmark(
    String bookId, {
    required ReaderLocator locator,
    String? label,
  }) async {
    try {
      final id = IdGenerator.newId();
      await _db.notesDao.upsertBookmark(
        LocalBookmarksCompanion.insert(
          id: id,
          bookId: bookId,
          locatorType: locator.locatorType,
          locatorValue: locator.locatorValue,
          chapterIndex: Value(locator.chapterIndex),
          paragraphIndex: Value(locator.paragraphIndex),
          tokenIndex: Value(locator.tokenIndex),
          label: Value(_nullIfBlank(label)),
          syncStatus: const Value(SyncStatus.pendingUpload),
        ),
      );
      await _sync.enqueueBookmark(id);
      final row = await _db.notesDao.getBookmarkById(id);
      return Ok(_toBookmark(row!));
    } catch (e) {
      return Err(StorageFailure('Could not save bookmark: $e'));
    }
  }

  @override
  Future<Result<Note>> createNote(
    String bookId, {
    required ReaderLocator locator,
    required String noteText,
    String? selectedText,
  }) async {
    final text = noteText.trim();
    if (text.isEmpty) {
      return const Err(ValidationFailure('Note text is empty.'));
    }
    try {
      final id = IdGenerator.newId();
      await _db.notesDao.upsertNote(
        LocalNotesCompanion.insert(
          id: id,
          bookId: bookId,
          locatorType: locator.locatorType,
          locatorValue: locator.locatorValue,
          noteText: text,
          selectedText: Value(_nullIfBlank(selectedText)),
          syncStatus: const Value(SyncStatus.pendingUpload),
        ),
      );
      await _sync.enqueueNote(id);
      final row = await _db.notesDao.getNoteById(id);
      return Ok(_toNote(row!));
    } catch (e) {
      return Err(StorageFailure('Could not save note: $e'));
    }
  }

  @override
  Stream<List<Bookmark>> watchBookmarks(String bookId) =>
      _db.notesDao.watchBookmarksForBook(bookId).map(
            (rows) => rows.map(_toBookmark).toList(growable: false),
          );

  @override
  Stream<List<Note>> watchNotes(String bookId) =>
      _db.notesDao.watchNotesForBook(bookId).map(
            (rows) => rows.map(_toNote).toList(growable: false),
          );

  @override
  Future<Result<void>> deleteBookmark(String id) async {
    try {
      await _db.notesDao.softDeleteBookmark(id);
      await _sync.enqueueBookmark(id); // snapshot now carries the tombstone
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure('Could not delete bookmark: $e'));
    }
  }

  @override
  Future<Result<void>> deleteNote(String id) async {
    try {
      await _db.notesDao.softDeleteNote(id);
      await _sync.enqueueNote(id); // snapshot now carries the tombstone
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure('Could not delete note: $e'));
    }
  }

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Bookmark _toBookmark(LocalBookmark row) => Bookmark(
        id: row.id,
        bookId: row.bookId,
        locatorType: row.locatorType,
        locatorValue: row.locatorValue,
        createdAt: DateTime.tryParse(row.createdAt),
        label: row.label,
      );

  Note _toNote(LocalNote row) => Note(
        id: row.id,
        bookId: row.bookId,
        noteText: row.noteText,
        locatorType: row.locatorType,
        locatorValue: row.locatorValue,
        createdAt: DateTime.tryParse(row.createdAt),
        selectedText: row.selectedText,
      );
}
