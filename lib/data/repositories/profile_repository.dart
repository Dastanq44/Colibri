import '../../core/result/result.dart';

/// Boundary for user profile data. Implemented in Phase 3.
abstract interface class ProfileRepository {
  /// Ensures a profile row exists for the current user (created on first
  /// sign-up with default locale and goals).
  Future<Result<void>> ensureProfileForCurrentUser();

  Future<Result<void>> updateDisplayName(String displayName);

  Future<Result<void>> updateLocale(String locale);

  // TODO(phase3): expose a typed Profile domain model + read methods.
}
