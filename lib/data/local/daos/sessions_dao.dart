import 'package:drift/drift.dart';

import '../app_database.dart';
import '../db_time.dart';
import '../tables/reading_tables.dart';

part 'sessions_dao.g.dart';

/// Append-only reading sessions used for stats/goals (Phase later).
@DriftAccessor(tables: [LocalReadingSessions])
class SessionsDao extends DatabaseAccessor<AppDatabase>
    with _$SessionsDaoMixin {
  SessionsDao(super.db);

  Future<void> startSession(LocalReadingSessionsCompanion session) =>
      into(localReadingSessions).insert(session);

  Future<void> endSession(
    String id, {
    required int durationSeconds,
    int? wordsRead,
    int? avgWpm,
  }) async {
    await (update(localReadingSessions)..where((s) => s.id.equals(id))).write(
      LocalReadingSessionsCompanion(
        endedAt: Value(dbNow()),
        durationSeconds: Value(durationSeconds),
        wordsRead: Value(wordsRead),
        avgWpm: Value(avgWpm),
      ),
    );
  }

  Future<List<LocalSession>> getForBook(String bookId) =>
      (select(localReadingSessions)..where((s) => s.bookId.equals(bookId)))
          .get();

  /// Removes a session (used for below-threshold noise sessions).
  Future<void> deleteSession(String id) =>
      (delete(localReadingSessions)..where((s) => s.id.equals(id))).go();
}
