import 'package:drift/drift.dart';

import '../app_database.dart';
import '../db_time.dart';
import '../sync_status.dart';
import '../tables/annotation_tables.dart';

part 'notes_dao.g.dart';

/// Notes and bookmarks. Deletions are soft (set `deletedAt` + sync status) so
/// they can be reconciled with the cloud later.
@DriftAccessor(tables: [LocalNotes, LocalBookmarks])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  // --- Notes ---

  Future<void> upsertNote(LocalNotesCompanion note) =>
      into(localNotes).insertOnConflictUpdate(note);

  Future<List<LocalNote>> getNotesForBook(String bookId) =>
      (select(localNotes)
            ..where((n) => n.bookId.equals(bookId) & n.deletedAt.isNull()))
          .get();

  Stream<List<LocalNote>> watchNotesForBook(String bookId) =>
      (select(localNotes)
            ..where((n) => n.bookId.equals(bookId) & n.deletedAt.isNull())
            ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
          .watch();

  /// By id, including soft-deleted rows (sync snapshots need the tombstone).
  Future<LocalNote?> getNoteById(String id) =>
      (select(localNotes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<void> softDeleteNote(String id) async {
    await (update(localNotes)..where((n) => n.id.equals(id))).write(
      LocalNotesCompanion(
        deletedAt: Value(dbNow()),
        syncStatus: const Value(SyncStatus.deleted),
      ),
    );
  }

  // --- Bookmarks ---

  Future<void> upsertBookmark(LocalBookmarksCompanion bookmark) =>
      into(localBookmarks).insertOnConflictUpdate(bookmark);

  Future<List<LocalBookmark>> getBookmarksForBook(String bookId) =>
      (select(localBookmarks)
            ..where((b) => b.bookId.equals(bookId) & b.deletedAt.isNull()))
          .get();

  Stream<List<LocalBookmark>> watchBookmarksForBook(String bookId) =>
      (select(localBookmarks)
            ..where((b) => b.bookId.equals(bookId) & b.deletedAt.isNull())
            ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
          .watch();

  /// By id, including soft-deleted rows (sync snapshots need the tombstone).
  Future<LocalBookmark?> getBookmarkById(String id) =>
      (select(localBookmarks)..where((b) => b.id.equals(id)))
          .getSingleOrNull();

  Future<void> softDeleteBookmark(String id) async {
    await (update(localBookmarks)..where((b) => b.id.equals(id))).write(
      LocalBookmarksCompanion(
        deletedAt: Value(dbNow()),
        syncStatus: const Value(SyncStatus.deleted),
      ),
    );
  }
}
