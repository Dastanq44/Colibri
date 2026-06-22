import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../data/repositories/library_repository.dart';
import '../../../data/repositories/local_library_repository.dart';
import '../../import/application/import_providers.dart';
import '../domain/library_book.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LocalLibraryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(fileStorageServiceProvider),
  );
});

/// Reactive list of the user's local books for "My Books".
final myBooksProvider = StreamProvider<List<LibraryBook>>((ref) {
  return ref.watch(libraryRepositoryProvider).watchMyBooks();
});
