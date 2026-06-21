import '../../core/result/result.dart';

/// Boundary for authentication. Implemented in Phase 3 on top of Supabase Auth.
/// UI/state must depend on this interface, never on Supabase directly.
abstract interface class AuthRepository {
  /// Current signed-in user id, or `null` when signed out.
  String? get currentUserId;

  /// Emits `true` while a user is signed in, `false` otherwise.
  Stream<bool> authStateChanges();

  Future<Result<void>> signUp({required String email, required String password});

  Future<Result<void>> signIn({required String email, required String password});

  Future<Result<void>> signOut();

  Future<Result<void>> sendPasswordReset(String email);

  Future<Result<void>> deleteAccount();
}
