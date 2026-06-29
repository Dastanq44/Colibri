import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../data/remote/supabase_client_provider.dart';
import '../../../data/repositories/sync_repository.dart';
import '../data/local_sync_queue_repository.dart';
import '../data/supabase_sync_repository.dart';

/// Builds/coalesces queue items from local changes.
final localSyncQueueRepositoryProvider = Provider<LocalSyncQueueRepository>(
  (ref) => LocalSyncQueueRepository(ref.watch(appDatabaseProvider)),
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

/// Count of local changes not yet synced (anything not `done`).
final pendingSyncCountProvider = FutureProvider<int>(
  (ref) => ref.watch(localSyncQueueRepositoryProvider).pendingCount(),
);
