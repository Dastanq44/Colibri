import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/supabase_client_provider.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/supabase_auth_repository.dart';
import '../domain/auth_user.dart';

/// Concrete [AuthRepository] bound to the (possibly null) Supabase client.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

/// Stream of auth state changes (signed-in user or null).
final authStateChangesProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// The current user, falling back to the repository's synchronous value before
/// the stream emits its first event.
final currentUserProvider = Provider<AuthUser?>((ref) {
  final state = ref.watch(authStateChangesProvider);
  return state.valueOrNull ?? ref.watch(authRepositoryProvider).currentUser;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
});

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Whether a Supabase backend is configured this run. Application-layer view
/// of the data-layer flag so presentation code never imports `data/remote`.
final backendConfiguredProvider = Provider<bool>((ref) {
  return ref.watch(supabaseConfiguredProvider);
});
