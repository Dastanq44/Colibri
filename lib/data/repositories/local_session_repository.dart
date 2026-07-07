import '../../core/utils/id_generator.dart';
import '../local/app_database.dart';

/// Records reading sessions locally (plan §10.2 local_reading_sessions).
/// Sessions feed the profile's average WPM and, later, goals/streaks and
/// analytics KPIs. Append-only; cloud sync of sessions is post-MVP.
class LocalSessionRepository {
  LocalSessionRepository(this._db);

  /// Sessions shorter than this are noise (accidental opens, instant mode
  /// flips) and are not persisted.
  static const Duration minimumDuration = Duration(seconds: 5);

  final AppDatabase _db;

  /// Opens a session and returns its id.
  Future<String> startSession({
    required String bookId,
    required String mode,
  }) async {
    final id = IdGenerator.newId();
    await _db.sessionsDao.startSession(
      LocalReadingSessionsCompanion.insert(id: id, bookId: bookId, mode: mode),
    );
    return id;
  }

  /// Closes a session. Sessions below [minimumDuration] are deleted instead
  /// of recorded. [wordsRead] only applies to fast mode; [avgWpm] is the
  /// measured pace, not the WPM setting.
  Future<void> endSession(
    String id, {
    required Duration duration,
    int? wordsRead,
    int? avgWpm,
  }) async {
    if (duration < minimumDuration) {
      await _db.sessionsDao.deleteSession(id);
      return;
    }
    await _db.sessionsDao.endSession(
      id,
      durationSeconds: duration.inSeconds,
      wordsRead: wordsRead,
      avgWpm: avgWpm,
    );
  }
}
