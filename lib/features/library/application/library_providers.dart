import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../data/local/database_providers.dart';
import '../../../data/remote/supabase_client_provider.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/local_library_repository.dart';
import '../../import/application/import_providers.dart';
import '../../sync/application/sync_providers.dart';
import '../domain/library_book.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LocalLibraryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(fileStorageServiceProvider),
    ref.watch(localSyncQueueRepositoryProvider),
    client: ref.watch(supabaseClientProvider),
  );
});

/// One cloud-shelf pull per app session (the tab shell keeps this alive).
/// Failures are silent — the local library never depends on the backend.
final libraryCloudRefreshProvider = FutureProvider<int>((ref) async {
  final result = await ref.watch(libraryRepositoryProvider).refreshFromCloud();
  return switch (result) {
    Ok(value: final added) => added,
    Err() => 0,
  };
});

/// Reactive list of the user's local books for "My Books".
final myBooksProvider = StreamProvider<List<LibraryBook>>((ref) {
  return ref.watch(libraryRepositoryProvider).watchMyBooks();
});

/// Favourite books (subset of [myBooksProvider], reactive).
final favoriteBooksProvider = Provider<List<LibraryBook>>((ref) {
  final books = ref.watch(myBooksProvider).valueOrNull ?? const <LibraryBook>[];
  return books.where((b) => b.isFavorite).toList();
});

/// One best-effort covers backfill per app session, for EPUBs imported before
/// cover extraction existed. Watched by the library screen; silent by design.
final coverBackfillProvider = FutureProvider<int>((ref) {
  return ref.watch(libraryRepositoryProvider).backfillCovers();
});
