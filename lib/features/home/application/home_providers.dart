import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/bookshelf_status.dart';
import '../../library/application/library_providers.dart';
import '../../library/domain/library_book.dart';

/// Books for the Home "Continue Reading" section: most recently opened first,
/// capped at one large + two small cards (plan section 7.2). Only books the
/// user is actively reading qualify — finished/abandoned/want-to-read books
/// have nothing to "continue", and never-opened ones live in My Books.
final continueReadingProvider = Provider<AsyncValue<List<LibraryBook>>>((ref) {
  return ref.watch(myBooksProvider).whenData((books) {
    final opened = books
        .where((b) =>
            b.lastOpenedAt != null && b.status == BookShelfStatus.reading)
        .toList()
      ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
    return opened.take(3).toList(growable: false);
  });
});

/// Whether the user has any books at all (drives Home's empty state).
final hasAnyBooksProvider = Provider<AsyncValue<bool>>((ref) {
  return ref.watch(myBooksProvider).whenData((books) => books.isNotEmpty);
});
