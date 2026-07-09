import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../../shared/widgets/book_cover.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog_book.dart';

/// Catalog (plan 7.3): searchable, paginated list of cloud catalog books.
/// Category/language/format filters come later; search is title-based MVP.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        ref.read(catalogListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) ref.read(catalogListProvider.notifier).search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(catalogListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.catalogTitle)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.catalogSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _CatalogBody(state: state, scroll: _scroll)),
        ],
      ),
    );
  }
}

class _CatalogBody extends ConsumerWidget {
  const _CatalogBody({required this.state, required this.scroll});

  final CatalogListState state;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (state.failure != null && state.books.isEmpty) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        text: l10n.catalogUnavailable,
        action: TextButton(
          onPressed: () => ref.read(catalogListProvider.notifier).retry(),
          child: Text(l10n.catalogRetry),
        ),
      );
    }
    if (state.loading && state.books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.books.isEmpty) {
      return _Message(
        icon: Icons.explore_outlined,
        text: state.query.trim().isEmpty
            ? l10n.catalogEmpty
            : l10n.searchNoResults,
      );
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: state.books.length + (state.loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.books.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _CatalogTile(book: state.books[index]);
      },
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.book});

  final CatalogBook book;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = (book.language ?? '').toUpperCase();
    final author = book.authorDisplay.isEmpty
        ? l10n.libraryUnknownAuthor
        : book.authorDisplay;
    final byline = language.isEmpty ? author : '$author · $language';

    // Same card treatment as My Books: cover box + title/author in a card.
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: BookCover(coverUrl: book.coverUrl, width: 44, height: 62),
        trailing: const Icon(Icons.chevron_right),
        title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            byline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        onTap: () => context.push(AppRoutes.bookDetail(book.id)),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...<Widget>[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
