import '../../../data/local/app_database.dart';

/// Persists whether the user has completed (or skipped) onboarding. Local
/// only — onboarding is shown once per install, before any account exists.
class OnboardingRepository {
  OnboardingRepository(this._db);

  static const String _key = 'onboarding_completed';

  final AppDatabase _db;

  Future<bool> isCompleted() async =>
      await _db.keyValueDao.getValue(_key) == 'true';

  Future<void> markCompleted() => _db.keyValueDao.setValue(_key, 'true');
}
