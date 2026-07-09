import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/widgets/app_loader.dart';
import '../../../app/widgets/confirm_sheet.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/glass_buttons.dart';
import '../../../shared/models/bookshelf_status.dart';
import '../../../shared/widgets/book_cover.dart';
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

/// "My Books" — local library backed by Drift. Book covers, swipeable status
/// pages with a scrollable glass category bar, and per-book actions via a
/// native pull-down menu.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final booksAsync = ref.watch(myBooksProvider);
    // Kick off the once-per-session cloud-shelf pull (no-op signed out) and
    // the cover backfill for books imported before cover support.
    ref.watch(libraryCloudRefreshProvider);
    ref.watch(coverBackfillProvider);

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
        loading: () => const Center(child: AppLoader()),
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

/// Swipeable status pages + a scrollable glass category bar. Swiping the page
/// left/right changes the category; tapping a pill jumps to it. The bar is
/// not fixed-width: categories can scroll beyond the visible edge.
class _LibraryTabs extends StatefulWidget {
  const _LibraryTabs({required this.books});

  final List<LibraryBook> books;

  @override
  State<_LibraryTabs> createState() => _LibraryTabsState();
}

class _LibraryTabsState extends State<_LibraryTabs> {
  final PageController _pages = PageController();
  final ScrollController _barScroll = ScrollController();
  final List<GlobalKey> _pillKeys =
      List<GlobalKey>.generate(_statusTabs.length, (_) => GlobalKey());
  int _selected = 0;

  @override
  void dispose() {
    _pages.dispose();
    _barScroll.dispose();
    super.dispose();
  }

  void _select(int index, {bool fromSwipe = false}) {
    if (index == _selected) return;
    setState(() => _selected = index);
    if (!fromSwipe) {
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    // Keep the active pill visible as the selection moves.
    final ctx = _pillKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        alignment: 0.5,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: _CategoryBar(
            controller: _barScroll,
            labels: <String>[
              for (final status in _statusTabs) statusLabel(l10n, status),
            ],
            pillKeys: _pillKeys,
            selected: _selected,
            onTap: _select,
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (i) => _select(i, fromSwipe: true),
            children: <Widget>[
              for (final status in _statusTabs)
                _BookList(
                  books:
                      widget.books.where((b) => b.status == status).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Scrollable capsule bar with a **sliding Liquid Glass thumb**: the capsule
/// glides between categories (rather than blinking out/in) and the labels
/// scroll past the screen edge. Frosted-glass track underneath.
class _CategoryBar extends StatefulWidget {
  const _CategoryBar({
    required this.controller,
    required this.labels,
    required this.pillKeys,
    required this.selected,
    required this.onTap,
  });

  final ScrollController controller;
  final List<String> labels;
  final List<GlobalKey> pillKeys;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar> {
  final GlobalKey _stackKey = GlobalKey();
  List<Rect> _pillRects = const <Rect>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  /// Measures each pill's rect within the scroll content, so the thumb can
  /// be positioned (and animated) in the same coordinate space.
  void _measure() {
    final stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !mounted) return;
    final rects = <Rect>[];
    for (final key in widget.pillKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      rects.add(box.localToGlobal(Offset.zero, ancestor: stackBox) & box.size);
    }
    setState(() => _pillRects = rects);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRects = _pillRects.length == widget.labels.length;
    final Rect? thumb = hasRects ? _pillRects[widget.selected] : null;

    return GlassSurface(
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      blur: 14,
      padding: const EdgeInsets.all(3),
      child: SizedBox(
        height: 38,
        child: SingleChildScrollView(
          controller: widget.controller,
          scrollDirection: Axis.horizontal,
          child: Stack(
            key: _stackKey,
            children: <Widget>[
              // Sliding Liquid Glass thumb — glides to the active category.
              if (thumb != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: thumb.left,
                  top: 0,
                  width: thumb.width,
                  height: 38,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const GlassPanel(
                        radius: 19,
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              Row(
                children: <Widget>[
                  for (var i = 0; i < widget.labels.length; i++)
                    Padding(
                      key: widget.pillKeys[i],
                      padding: EdgeInsets.only(
                          right: i == widget.labels.length - 1 ? 0 : 4),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        minimumSize: Size.zero,
                        onPressed: () => widget.onTap(i),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.titleSmall!.copyWith(
                            // Constant weight keeps pill widths stable so the
                            // measured thumb rects never drift.
                            fontWeight: FontWeight.w600,
                            color: i == widget.selected
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          child: Text(widget.labels[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    // Modern floating glass confirmation card.
    final confirmed = await showModernConfirmSheet(
      context,
      title: l10n.removeBookTitle,
      message: l10n.removeBookBody,
      confirmLabel: l10n.libraryRemove,
      cancelLabel: l10n.dialogCancel,
    );
    if (confirmed) {
      await ref.read(libraryRepositoryProvider).removeBookFromLibrary(book.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isIos = theme.platform == TargetPlatform.iOS;
    final author =
        book.authorDisplay.isEmpty ? l10n.libraryUnknownAuthor : book.authorDisplay;

    final favoriteLabel = book.isFavorite
        ? l10n.libraryRemoveFromFavorites
        : l10n.libraryAddToFavorites;

    void onMenuIndex(int index) {
      // Items: 0 favourite, 1..4 statuses, 5 divider, 6 remove.
      if (index == 0) {
        ref.read(libraryRepositoryProvider).setFavorite(book.id, !book.isFavorite);
      } else if (index >= 1 && index <= _statusTabs.length) {
        ref
            .read(libraryRepositoryProvider)
            .updateBookStatus(book.id, _statusTabs[index - 1]);
      } else {
        _confirmRemove(context, ref, l10n);
      }
    }

    final Widget menu = isIos
        ? CNPopupMenuButton.icon(
            buttonIcon: const CNSymbol('ellipsis', size: 16),
            size: 34,
            buttonStyle: CNButtonStyle.plain,
            items: <CNPopupMenuEntry>[
              CNPopupMenuItem(
                label: favoriteLabel,
                icon: CNSymbol(book.isFavorite ? 'heart.fill' : 'heart'),
              ),
              for (final status in _statusTabs)
                CNPopupMenuItem(label: statusLabel(l10n, status)),
              const CNPopupMenuDivider(),
              CNPopupMenuItem(
                label: l10n.libraryRemove,
                icon: const CNSymbol('trash'),
              ),
            ],
            onSelected: onMenuIndex,
          )
        : PopupMenuButton<int>(
            tooltip: l10n.libraryChangeStatus,
            onSelected: onMenuIndex,
            itemBuilder: (context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(value: 0, child: Text(favoriteLabel)),
              for (var i = 0; i < _statusTabs.length; i++)
                PopupMenuItem<int>(
                  value: i + 1,
                  child: Text(statusLabel(l10n, _statusTabs[i])),
                ),
              const PopupMenuDivider(),
              PopupMenuItem<int>(
                value: _statusTabs.length + 2,
                child: Text(l10n.libraryRemove),
              ),
            ],
          );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: InkWell(
          onTap: () => context.push(
            !book.hasLocalFile && book.cloudBookId != null
                ? AppRoutes.bookDetail(book.cloudBookId!)
                : AppRoutes.reader(book.id),
          ),
          child: Row(
            children: <Widget>[
              BookCover(coverPath: book.coverPath, width: 52, height: 74),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (book.isFavorite) ...<Widget>[
                          const SizedBox(width: 6),
                          Icon(CupertinoIcons.heart_fill,
                              size: 14, color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${statusLabel(l10n, book.status)} · ${book.percent.round()}%'
                      '${book.lastOpenedAt != null ? ' · ${l10n.libraryLastOpened(_formatDate(book.lastOpenedAt!))}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              menu,
            ],
          ),
        ),
      ),
    );
  }
}
