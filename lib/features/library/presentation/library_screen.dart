import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/widgets/glass_buttons.dart';
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

/// "My Books" — local library backed by Drift. Shows imported books filtered
/// by status (native iOS segmented control), with an import action and
/// per-book status/remove actions via a native pull-down menu.
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
        actions: glassActions(<Widget>[
          GlassIconButton(
            sfSymbol: 'plus',
            fallbackIcon: Icons.add,
            semanticLabel: l10n.importTitle,
            onPressed: () => context.push(AppRoutes.importBook),
          ),
        ]),
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator(radius: 14)),
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
            Icon(CupertinoIcons.book,
                size: 64, color: theme.colorScheme.primary),
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
              icon: const Icon(CupertinoIcons.square_arrow_up),
              label: Text(l10n.importChooseFile),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status filter as a native iOS segmented control (real `UISegmentedControl`
/// via `cupertino_native`) driving a single list; Material `TabBar` reads as
/// Android. Falls back to `CupertinoSlidingSegmentedControl` off-iOS.
class _LibraryTabs extends StatefulWidget {
  const _LibraryTabs({required this.books});

  final List<LibraryBook> books;

  @override
  State<_LibraryTabs> createState() => _LibraryTabsState();
}

class _LibraryTabsState extends State<_LibraryTabs> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = <String>[
      for (final status in _statusTabs) statusLabel(l10n, status),
    ];
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final status = _statusTabs[_selected];

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: isIos
                ? CNSegmentedControl(
                    labels: labels,
                    selectedIndex: _selected,
                    onValueChanged: (i) => setState(() => _selected = i),
                  )
                : CupertinoSlidingSegmentedControl<int>(
                    groupValue: _selected,
                    children: <int, Widget>{
                      for (var i = 0; i < labels.length; i++)
                        i: Text(labels[i]),
                    },
                    onValueChanged: (i) =>
                        setState(() => _selected = i ?? _selected),
                  ),
          ),
        ),
        Expanded(
          child: _BookList(
            books: widget.books.where((b) => b.status == status).toList(),
          ),
        ),
      ],
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
      // iOS-native confirmation: centered alert with a destructive action.
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(l10n.removeBookTitle),
          content: Text(l10n.removeBookBody),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.dialogCancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
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

  /// Menu entries in display order; index-aligned with [_actionAt].
  List<_CardAction> get _actions => <_CardAction>[
        for (final status in _statusTabs) _CardAction.status(status),
        const _CardAction.remove(),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isIos = theme.platform == TargetPlatform.iOS;
    final author =
        book.authorDisplay.isEmpty ? l10n.libraryUnknownAuthor : book.authorDisplay;
    final actions = _actions;

    // Native iOS pull-down menu (UIMenu) instead of the Android-style
    // Material dropdown; Material PopupMenuButton stays as the fallback.
    final Widget menu = isIos
        ? CNPopupMenuButton.icon(
            buttonIcon: const CNSymbol('ellipsis', size: 16),
            size: 34,
            buttonStyle: CNButtonStyle.plain,
            items: <CNPopupMenuEntry>[
              for (final status in _statusTabs)
                CNPopupMenuItem(label: statusLabel(l10n, status)),
              const CNPopupMenuDivider(),
              CNPopupMenuItem(
                label: l10n.libraryRemove,
                icon: const CNSymbol('trash'),
              ),
            ],
            onSelected: (index) {
              // Divider is not selectable; indexes map straight to actions
              // (0..3 statuses, 4 remove).
              final action =
                  index < _statusTabs.length ? actions[index] : actions.last;
              _onAction(context, ref, l10n, action);
            },
          )
        : PopupMenuButton<_CardAction>(
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
          );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
        trailing: menu,
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
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
