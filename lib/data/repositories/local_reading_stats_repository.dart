import '../../features/profile/domain/reading_stats.dart';
import '../local/app_database.dart';

/// Live local reading stats over the bookshelf and session tables.
class LocalReadingStatsRepository {
  LocalReadingStatsRepository(this._db);

  final AppDatabase _db;

  Stream<ReadingStats> watchStats() {
    final query = _db.customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM local_bookshelf WHERE status = 'finished')
          AS books_read,
        (SELECT COUNT(*) FROM local_bookshelf WHERE status = 'reading')
          AS current_books,
        (SELECT AVG(avg_wpm) FROM local_reading_sessions
          WHERE avg_wpm IS NOT NULL) AS avg_wpm
      ''',
      readsFrom: {_db.localBookshelf, _db.localReadingSessions},
    );
    return query.watchSingle().map(
          (row) => ReadingStats(
            booksRead: row.read<int>('books_read'),
            currentBooks: row.read<int>('current_books'),
            avgWpm: row.readNullable<double>('avg_wpm')?.round(),
          ),
        );
  }
}
