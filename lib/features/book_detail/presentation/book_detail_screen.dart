import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/result/result.dart';
import '../../auth/application/auth_providers.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/domain/catalog_book.dart';

/// Book detail for catalog books (plan 7.5): metadata, add-to-shelf CTA when
/// signed in, and a reviews placeholder. Locally imported books open straight
/// into the reader from Home/My Books, so this screen is catalog-scoped.
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(catalogBookProvider(bookId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookDetailTitle)),
      body: switch (book) {
        AsyncData(value: final CatalogBook loaded) =>
          _Detail(book: loaded, l10n: l10n),
        AsyncData() || AsyncError() => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.catalogUnavailable, textAlign: TextAlign.center),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({required this.book, required this.l10n});

  final CatalogBook book;
  final AppLocalizations l10n;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  bool _adding = false;
  bool _added = false;

  Future<void> _addToShelf() async {
    setState(() => _adding = true);
    final result =
        await ref.read(catalogRepositoryProvider).addToShelf(widget.book.id);
    if (!mounted) return;
    setState(() {
      _adding = false;
      _added = result is Ok;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result is Ok
            ? widget.l10n.bookDetailAdded
            : widget.l10n.annotationSaveFailed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = widget.book;
    final l10n = widget.l10n;
    final signedIn = ref.watch(isSignedInProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 72,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_outlined, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(book.title, style: theme.textTheme.titleLarge),
                  if (book.subtitle != null)
                    Text(book.subtitle!, style: theme.textTheme.titleSmall),
                  if (book.authorDisplay.isNotEmpty)
                    Text(book.authorDisplay,
                        style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    <String>[
                      book.format.toUpperCase(),
                      if (book.language != null) book.language!.toUpperCase(),
                    ].join(' · '),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (signedIn)
          FilledButton.icon(
            onPressed: _adding || _added ? null : _addToShelf,
            icon: Icon(_added ? Icons.check : Icons.library_add_outlined),
            label: Text(
                _added ? l10n.bookDetailAdded : l10n.bookDetailAddToShelf),
          )
        else
          Text(l10n.bookDetailSignInToAdd,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center),
        const SizedBox(height: 16),
        if (book.description != null && book.description!.isNotEmpty) ...[
          Text(l10n.bookDetailAbout, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(book.description!),
          const SizedBox(height: 16),
        ],
        // Reviews land in Phase 13.
        Text(l10n.bookDetailReviews, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(l10n.comingSoon, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
