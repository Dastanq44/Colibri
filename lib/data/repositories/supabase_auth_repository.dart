// Hide Supabase's AuthUser; this app uses its own domain AuthUser model
// (Supabase's `User` is still used internally).
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../core/errors/failures.dart';
import '../../core/result/result.dart';
import '../../features/auth/domain/auth_user.dart';
import 'auth_repository.dart';

/// Supabase-backed [AuthRepository].
///
/// Holds a nullable [SupabaseClient]: when the backend is not configured (dev
/// without keys) the client is null and every action returns a typed
/// [BackendUnavailableFailure] instead of crashing.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient? _client;

  AuthUser? _toUser(User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email);

  @override
  AuthUser? get currentUser =>
      _client == null ? null : _toUser(_client.auth.currentUser);

  @override
  String? get currentUserId => currentUser?.id;

  @override
  Stream<AuthUser?> authStateChanges() {
    final client = _client;
    if (client == null) return Stream<AuthUser?>.value(null);
    return client.auth.onAuthStateChange.map((s) => _toUser(s.session?.user));
  }

  @override
  Future<Result<void>> signUp({
    required String email,
    required String password,
    String? displayName,
  }) {
    return _guard((client) async {
      await client.auth.signUp(
        email: email,
        password: password,
        data: (displayName != null && displayName.isNotEmpty)
            ? <String, dynamic>{'display_name': displayName}
            : null,
      );
    });
  }

  @override
  Future<Result<void>> signIn({
    required String email,
    required String password,
  }) {
    return _guard((client) async {
      await client.auth.signInWithPassword(email: email, password: password);
    });
  }

  @override
  Future<Result<void>> signOut() {
    return _guard((client) async {
      await client.auth.signOut();
    });
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) {
    return _guard((client) async {
      await client.auth.resetPasswordForEmail(email);
    });
  }

  @override
  Future<Result<void>> deleteAccount() async {
    if (_client == null) return const Err(BackendUnavailableFailure());
    // Self-deletion requires a privileged server step (service role). Until an
    // edge function exists, surface a clear, typed failure rather than
    // pretending the account was deleted.
    return const Err(
      UnknownFailure('Account deletion is not available yet.'),
    );
  }

  /// Runs [action] with a non-null client, mapping common Supabase errors to
  /// typed [Failure]s. Returns [BackendUnavailableFailure] when unconfigured.
  Future<Result<void>> _guard(
    Future<void> Function(SupabaseClient client) action,
  ) async {
    final client = _client;
    if (client == null) return const Err(BackendUnavailableFailure());
    try {
      await action(client);
      return const Ok(null);
    } on AuthException catch (e) {
      return Err(_mapAuthError(e));
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  Failure _mapAuthError(AuthException e) {
    final status = int.tryParse(e.statusCode ?? '');
    if (status == 401 || status == 403) return UnauthorizedFailure(e.message);
    return ValidationFailure(e.message);
  }
}
