import 'package:drift/drift.dart';

import '../app_database.dart';
import '../db_time.dart';
import '../sync_status.dart';
import '../tables/book_tables.dart';

part 'bookshelf_dao.g.dart';

/// CRUD for the personal shelf (reading status per book).
@DriftAccessor(tables: [LocalBookshelf])
class BookshelfDao extends DatabaseAccessor<AppDatabase>
    with _$BookshelfDaoMixin {
  BookshelfDao(super.db);

  Future<void> upsertEntry(LocalBookshelfCompanion entry) =>
      into(localBookshelf).insertOnConflictUpdate(entry);

  Future<LocalShelfEntry?> getByBookId(String bookId) =>
      (select(localBookshelf)..where((e) => e.bookId.equals(bookId)))
          .getSingleOrNull();

  /// Updates a book's reading status and marks it for sync.
  Future<void> setStatus(String bookId, String status) async {
    await (update(localBookshelf)..where((e) => e.bookId.equals(bookId))).write(
      LocalBookshelfCompanion(
        status: Value(status),
        syncStatus: const Value(SyncStatus.pendingUpdate),
        lastOpenedAt: Value(dbNow()),
      ),
    );
  }

  /// Stamps the shelf's last-opened time and marks it for sync. No-op (no
  /// crash) when there is no shelf row for [bookId].
  Future<void> markOpened(String bookId) async {
    await (update(localBookshelf)..where((e) => e.bookId.equals(bookId))).write(
      LocalBookshelfCompanion(
        lastOpenedAt: Value(dbNow()),
        syncStatus: const Value(SyncStatus.pendingUpdate),
      ),
    );
  }

  Stream<List<LocalShelfEntry>> watchByStatus(String status) =>
      (select(localBookshelf)..where((e) => e.status.equals(status))).watch();

  Future<List<LocalShelfEntry>> getAll() => select(localBookshelf).get();
}
