import 'package:drift/drift.dart';

import '../app_database.dart';
import '../db_time.dart';
import '../tables/book_tables.dart';

part 'books_dao.g.dart';

/// CRUD for locally-stored books. Repositories (not UI) depend on this.
@DriftAccessor(tables: [LocalBooks])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(super.db);

  Future<void> upsertBook(LocalBooksCompanion book) =>
      into(localBooks).insertOnConflictUpdate(book);

  Future<LocalBook?> getById(String id) =>
      (select(localBooks)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<List<LocalBook>> getAll() => select(localBooks).get();

  Stream<List<LocalBook>> watchAll() => select(localBooks).watch();

  Future<void> updateLastOpened(String id, {String? atIso}) async {
    await (update(localBooks)..where((b) => b.id.equals(id))).write(
      LocalBooksCompanion(
        lastOpenedAt: Value(atIso ?? dbNow()),
        updatedAt: Value(dbNow()),
      ),
    );
  }

  Future<int> deleteById(String id) =>
      (delete(localBooks)..where((b) => b.id.equals(id))).go();
}
