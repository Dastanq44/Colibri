import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../data/remote/supabase_client_provider.dart';
import '../../../data/repositories/local_reading_stats_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/supabase_profile_repository.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/profile.dart';
import '../domain/reading_stats.dart';

/// Concrete [ProfileRepository] bound to the (possibly null) Supabase client.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

/// Live local reading stats (books read / currently reading / avg WPM).
final readingStatsProvider = StreamProvider<ReadingStats>((ref) {
  return LocalReadingStatsRepository(ref.watch(appDatabaseProvider))
      .watchStats();
});

/// The current user's profile, or `null` when signed out / unavailable.
/// Re-fetches whenever the signed-in user changes.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  final result = await ref.watch(profileRepositoryProvider).getCurrentProfile();
  return result.when(ok: (profile) => profile, err: (_) => null);
});
