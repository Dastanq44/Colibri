import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/repositories/local_session_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalSessionRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LocalSessionRepository(db);
  });

  tearDown(() => db.close());

  test('start/end round-trips duration, words and measured WPM', () async {
    final id = await repo.startSession(bookId: 'b1', mode: 'fast');
    await repo.endSession(
      id,
      duration: const Duration(minutes: 2),
      wordsRead: 550,
      avgWpm: 275,
    );

    final session = (await db.sessionsDao.getForBook('b1')).single;
    expect(session.mode, 'fast');
    expect(session.durationSeconds, 120);
    expect(session.wordsRead, 550);
    expect(session.avgWpm, 275);
    expect(session.endedAt, isNotNull);
  });

  test('sessions below the minimum duration are dropped as noise', () async {
    final id = await repo.startSession(bookId: 'b1', mode: 'normal');
    await repo.endSession(id, duration: const Duration(seconds: 2));

    expect(await db.sessionsDao.getForBook('b1'), isEmpty);
  });

  test('normal-mode sessions record without WPM', () async {
    final id = await repo.startSession(bookId: 'b1', mode: 'normal');
    await repo.endSession(id, duration: const Duration(minutes: 1));

    final session = (await db.sessionsDao.getForBook('b1')).single;
    expect(session.avgWpm, isNull);
    expect(session.wordsRead, isNull);
  });
}
