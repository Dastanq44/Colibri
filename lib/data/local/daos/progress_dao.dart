import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/reading_tables.dart';

part 'progress_dao.g.dart';

/// Save/load of the latest reading position per book. The most important data
/// in the app — always written locally first.
@DriftAccessor(tables: [LocalReadingProgress])
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  Future<void> saveProgress(LocalReadingProgressCompanion progress) =>
      into(localReadingProgress).insertOnConflictUpdate(progress);

  Future<LocalProgress?> getByBookId(String bookId) =>
      (select(localReadingProgress)..where((p) => p.bookId.equals(bookId)))
          .getSingleOrNull();

  Stream<LocalProgress?> watchByBookId(String bookId) =>
      (select(localReadingProgress)..where((p) => p.bookId.equals(bookId)))
          .watchSingleOrNull();
}
