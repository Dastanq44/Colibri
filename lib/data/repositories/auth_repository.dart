import '../../core/result/result.dart';
import '../../features/auth/domain/auth_user.dart';

/// Boundary for authentication (Supabase Auth). UI/state depend on this
/// interface, never on Supabase directly.
abstract interface class AuthRepository {
  /// Current signed-in user, or `null` when signed out / backend unconfigured.
  AuthUser? get currentUser;

  /// Convenience accessor for the current user's id.
  String? get currentUserId;

  /// Emits the signed-in [AuthUser] (or `null` when signed out) on every auth
  /// state change.
  Stream<AuthUser?> authStateChanges();

  Future<Result<void>> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  Future<Result<void>> signIn({required String email, required String password});

  Future<Result<void>> signOut();

  Future<Result<void>> sendPasswordReset(String email);

  /// Account deletion. Self-deletion needs a privileged server step (edge
  /// function with the service role), so the client implementation is a
  /// placeholder until that exists (TASK-0305 / later).
  Future<Result<void>> deleteAccount();
}
