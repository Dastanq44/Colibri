import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../data/repositories/local_notes_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../sync/application/sync_providers.dart';
import '../domain/annotations.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return LocalNotesRepository(
    db: ref.watch(appDatabaseProvider),
    syncQueue: ref.watch(localSyncQueueRepositoryProvider),
  );
});

/// Live non-deleted bookmarks for a book, newest first.
final bookBookmarksProvider = StreamProvider.autoDispose
    .family<List<Bookmark>, String>(
  (ref, bookId) => ref.watch(notesRepositoryProvider).watchBookmarks(bookId),
);

/// Live non-deleted notes for a book, newest first.
final bookNotesProvider = StreamProvider.autoDispose.family<List<Note>, String>(
  (ref, bookId) => ref.watch(notesRepositoryProvider).watchNotes(bookId),
);
