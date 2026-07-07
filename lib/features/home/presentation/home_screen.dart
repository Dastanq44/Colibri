import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../../shared/models/book_format.dart';
import '../../catalog/domain/catalog_book.dart';
import '../../library/domain/library_book.dart';
import '../../recommendations/application/recommendation_providers.dart';
import '../../recommendations/domain/recommendation_rail.dart';
import '../application/home_providers.dart';

/// Home (plan section 7.2): greeting, Continue Reading from local progress,
/// goal card, and quick actions. Recommendation rails arrive with the catalog
/// connection (Phase 5); until then Home is fully local.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasBooks = ref.watch(hasAnyBooksProvider);
    final continueReading = ref.watch(continueReadingProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      // Loading renders blank (a local read, typically < 1 frame) so the
      // full layout doesn't flash before the empty state resolves.
      body: switch (hasBooks) {
        AsyncValue(isLoading: true, hasValue: false) =>
          const SizedBox.expand(),
        AsyncData(value: false) => _EmptyHome(l10n: l10n),
        _ => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              Text(l10n.homeGreeting,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              if (continueReading.valueOrNull?.isNotEmpty ?? false) ...<Widget>[
                _SectionHeader(l10n.homeContinueReading),
                _ContinueReadingSection(
                    books: continueReading.requireValue, l10n: l10n),
                const SizedBox(height: 16),
              ],
              _GoalCard(l10n: l10n),
              const SizedBox(height: 16),
              _SectionHeader(l10n.homeQuickActions),
              _QuickActions(l10n: l10n),
              for (final rail
                  in ref.watch(homeRailsProvider).valueOrNull ??
                      const <RecommendationRail>[]) ...<Widget>[
                const SizedBox(height: 16),
                _SectionHeader(_railTitle(l10n, rail.reason)),
                _RecommendationRailRow(rail: rail),
              ],
            ],
          ),
      },
    );
  }

  String _railTitle(AppLocalizations l10n, RecommendationReason reason) =>
      switch (reason) {
        RecommendationReason.sameAuthor => l10n.recoSameAuthor,
        RecommendationReason.goodForFastMode => l10n.recoGoodForFastMode,
        RecommendationReason.fromCatalog => l10n.recoFromCatalog,
      };
}

class _RecommendationRailRow extends ConsumerWidget {
  const _RecommendationRailRow({required this.rail});

  final RecommendationRail rail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: rail.books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final CatalogBook book = rail.books[index];
          return SizedBox(
            width: 150,
            child: Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  ref.read(analyticsRepositoryProvider).logEvent(
                    'recommendation_clicked',
                    params: {'reason': rail.reason.name},
                  );
                  context.push(AppRoutes.bookDetail(book.id));
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.menu_book_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        book.title,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (book.authorDisplay.isNotEmpty)
                        Text(
                          book.authorDisplay,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _ContinueReadingSection extends StatelessWidget {
  const _ContinueReadingSection({required this.books, required this.l10n});

  final List<LibraryBook> books;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _BookCard(book: books.first, large: true, l10n: l10n),
        for (final book in books.skip(1)) ...<Widget>[
          const SizedBox(height: 8),
          _BookCard(book: book, large: false, l10n: l10n),
        ],
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.large, required this.l10n});

  final LibraryBook book;
  final bool large;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = book.percent.round();
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(AppRoutes.reader(book.id)),
        child: Padding(
          padding: EdgeInsets.all(large ? 16 : 12),
          child: Row(
            children: <Widget>[
              Icon(
                _formatIcon(book.format),
                size: large ? 48 : 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      book.title,
                      style: large
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.bodyLarge,
                      maxLines: large ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (book.authorDisplay.isNotEmpty)
                      Text(
                        book.authorDisplay,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (book.percent / 100).clamp(0.0, 1.0),
                      semanticsLabel: l10n.readerProgressLabel,
                      semanticsValue: '$percent%',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: Text('$percent%', style: theme.textTheme.labelLarge),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _formatIcon(BookFormat format) => switch (format) {
        BookFormat.epub => Icons.menu_book_outlined,
        BookFormat.txt => Icons.article_outlined,
        BookFormat.pdf => Icons.picture_as_pdf_outlined,
      };
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.homeGoalTitle, style: theme.textTheme.titleSmall),
                  Text(l10n.homeGoalPlaceholder,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionButton(
            icon: Icons.file_upload_outlined,
            label: l10n.homeActionImport,
            onTap: () => context.push(AppRoutes.importBook),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.storefront_outlined,
            label: l10n.homeActionCatalog,
            onTap: () => context.go(AppRoutes.catalog),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.collections_bookmark_outlined,
            label: l10n.homeActionLibrary,
            onTap: () => context.go(AppRoutes.library),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.auto_stories_outlined,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(l10n.homeEmptyTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l10n.homeEmptyBody, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.importBook),
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(l10n.homeActionImport),
            ),
          ],
        ),
      ),
    );
  }
}
