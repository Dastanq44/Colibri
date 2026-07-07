import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../../shared/models/bookshelf_status.dart';
import '../application/library_providers.dart';
import '../domain/library_book.dart';

const List<BookShelfStatus> _statusTabs = <BookShelfStatus>[
  BookShelfStatus.reading,
  BookShelfStatus.finished,
  BookShelfStatus.abandoned,
  BookShelfStatus.wantToRead,
];

String statusLabel(AppLocalizations l10n, BookShelfStatus status) =>
    switch (status) {
      BookShelfStatus.reading => l10n.statusReading,
      BookShelfStatus.finished => l10n.statusFinished,
      BookShelfStatus.abandoned => l10n.statusAbandoned,
      BookShelfStatus.wantToRead => l10n.statusWantToRead,
    };

/// "My Books" — local library backed by Drift. Shows imported books grouped by
/// status, with an import action and per-book status/remove actions.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final booksAsync = ref.watch(myBooksProvider);
    // Kick off the once-per-session cloud-shelf pull (no-op signed out).
    ref.watch(libraryCloudRefreshProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.importTitle,
            icon: const Icon(Icons.add),
            onPressed: () => context.push(AppRoutes.importBook),
          ),
        ],
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.libraryLoadError)),
        data: (books) =>
            books.isEmpty ? _EmptyState(l10n: l10n) : _LibraryTabs(books: books),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.menu_book_outlined,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(l10n.libraryEmptyTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.libraryEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.importBook),
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(l10n.importChooseFile),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs({required this.books});

  final List<LibraryBook> books;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: _statusTabs.length,
      child: Column(
        children: <Widget>[
          TabBar(
            isScrollable: true,
            tabs: <Widget>[
              for (final status in _statusTabs) Tab(text: statusLabel(l10n, status)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                for (final status in _statusTabs)
                  _BookList(
                    books:
                        books.where((b) => b.status == status).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList({required this.books});

  final List<LibraryBook> books;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(
          l10n.libraryEmptyTitle,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: books.length,
      itemBuilder: (context, i) => _BookCard(book: books[i]),
    );
  }
}

class _BookCard extends ConsumerWidget {
  const _BookCard({required this.book});

  final LibraryBook book;

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    _CardAction action,
  ) async {
    final repo = ref.read(libraryRepositoryProvider);
    if (action.isRemove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.removeBookTitle),
          content: Text(l10n.removeBookBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.dialogCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.libraryRemove),
            ),
          ],
        ),
      );
      if (confirmed ?? false) {
        await repo.removeBookFromLibrary(book.id);
      }
    } else if (action.status != null) {
      await repo.updateBookStatus(book.id, action.status!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final author =
        book.authorDisplay.isEmpty ? l10n.libraryUnknownAuthor : book.authorDisplay;

    return Card(
      child: ListTile(
        leading: _FormatBadge(label: book.format.badge),
        title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(author),
            const SizedBox(height: 2),
            Text(
              '${statusLabel(l10n, book.status)} · ${book.percent.round()}%'
              '${book.lastOpenedAt != null ? ' · ${l10n.libraryLastOpened(_formatDate(book.lastOpenedAt!))}' : ''}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        isThreeLine: true,
        // Cloud-only entries (no downloaded file) open Book Detail — there
        // is nothing to read locally yet.
        onTap: () => context.push(
          !book.hasLocalFile && book.cloudBookId != null
              ? AppRoutes.bookDetail(book.cloudBookId!)
              : AppRoutes.reader(book.id),
        ),
        trailing: PopupMenuButton<_CardAction>(
          tooltip: l10n.libraryChangeStatus,
          onSelected: (action) => _onAction(context, ref, l10n, action),
          itemBuilder: (context) => <PopupMenuEntry<_CardAction>>[
            for (final status in _statusTabs)
              PopupMenuItem<_CardAction>(
                value: _CardAction.status(status),
                child: Text(statusLabel(l10n, status)),
              ),
            const PopupMenuDivider(),
            PopupMenuItem<_CardAction>(
              value: const _CardAction.remove(),
              child: Text(l10n.libraryRemove),
            ),
          ],
        ),
      ),
    );
  }
}

/// A book-card menu action: either change status, or remove.
class _CardAction {
  const _CardAction.status(this.status) : isRemove = false;
  const _CardAction.remove()
      : status = null,
        isRemove = true;

  final BookShelfStatus? status;
  final bool isRemove;
}

class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
