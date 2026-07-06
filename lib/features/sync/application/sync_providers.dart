import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../data/remote/supabase_client_provider.dart';
import '../../../data/repositories/sync_repository.dart';
import '../../auth/application/auth_providers.dart';
import '../data/local_sync_queue_repository.dart';
import '../data/supabase_sync_repository.dart';

/// Builds/coalesces queue items from local changes, stamped with the
/// signed-in user (null when signed out or when no backend is configured).
final localSyncQueueRepositoryProvider = Provider<LocalSyncQueueRepository>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return LocalSyncQueueRepository(
      ref.watch(appDatabaseProvider),
      // Null when signed out or unconfigured; never throws.
      currentUserId: () => client?.auth.currentUser?.id,
    );
  },
);

/// Processes the queue against Supabase (dev-safe when unconfigured/signed-out).
final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final repo = SupabaseSyncRepository(
    client: ref.watch(supabaseClientProvider),
    db: ref.watch(appDatabaseProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Live count of local changes not yet synced (anything not `done`) for the
/// active account. Backed by a Drift watch, so it updates as items are
/// enqueued/completed; rebuilt on auth changes so it follows the user.
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(localSyncQueueRepositoryProvider).watchPendingCount();
});
