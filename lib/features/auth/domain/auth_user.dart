/// Minimal, UI-independent representation of the signed-in user.
///
/// Intentionally small — just what the app needs to identify a session. Richer
/// profile data lives in the `Profile` domain model.
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}
