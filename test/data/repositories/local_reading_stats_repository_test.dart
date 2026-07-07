import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/repositories/local_reading_stats_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalReadingStatsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LocalReadingStatsRepository(db);
  });

  tearDown(() => db.close());

  Future<void> seedShelf(String bookId, String status) =>
      db.bookshelfDao.upsertEntry(
        LocalBookshelfCompanion.insert(bookId: bookId, status: status),
      );

  test('empty database yields zero counts and no avg WPM', () async {
    final stats = await repo.watchStats().first;
    expect(stats.booksRead, 0);
    expect(stats.currentBooks, 0);
    expect(stats.avgWpm, isNull);
  });

  test('counts finished and reading books', () async {
    await seedShelf('a', 'finished');
    await seedShelf('b', 'finished');
    await seedShelf('c', 'reading');
    await seedShelf('d', 'want_to_read');

    final stats = await repo.watchStats().first;
    expect(stats.booksRead, 2);
    expect(stats.currentBooks, 1);
  });

  test('averages measured session WPM, ignoring sessions without one',
      () async {
    await db.sessionsDao.startSession(LocalReadingSessionsCompanion.insert(
      id: 's1',
      bookId: 'a',
      mode: 'fast',
      avgWpm: const Value(300),
    ));
    await db.sessionsDao.startSession(LocalReadingSessionsCompanion.insert(
      id: 's2',
      bookId: 'a',
      mode: 'fast',
      avgWpm: const Value(400),
    ));
    await db.sessionsDao.startSession(LocalReadingSessionsCompanion.insert(
      id: 's3',
      bookId: 'a',
      mode: 'normal', // no measured WPM
    ));

    final stats = await repo.watchStats().first;
    expect(stats.avgWpm, 350);
  });
}
