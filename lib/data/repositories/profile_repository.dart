import '../../core/result/result.dart';
import '../../features/profile/domain/profile.dart';

/// Boundary for user profile data (the `profiles` table).
abstract interface class ProfileRepository {
  /// Loads the current user's profile.
  Future<Result<Profile>> getCurrentProfile();

  /// Ensures a profile row exists for the current user. A DB trigger normally
  /// creates it on sign-up; this is a safe client-side fallback.
  Future<Result<void>> ensureProfileForCurrentUser();

  Future<Result<void>> updateDisplayName(String displayName);

  Future<Result<void>> updateLocale(String locale);

  Future<Result<void>> updateGoals({int? goalDailyMinutes, int? goalBooksYear});
}
