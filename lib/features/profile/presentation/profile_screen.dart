import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/models/bookshelf_status.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../auth/application/auth_providers.dart';
import '../../library/application/library_providers.dart';
import '../../library/domain/library_book.dart';
import '../../sync/application/sync_controller.dart';
import '../../sync/application/sync_providers.dart';
import '../application/profile_providers.dart';

/// Basic profile screen. Shows a signed-out state with a sign-in CTA, or the
/// signed-in user's name/email, placeholder stats, and account actions.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: signedIn
          ? _SignedInBody(l10n: l10n)
          : _SignedOutBody(l10n: l10n),
    );
  }
}

class _SignedOutBody extends StatelessWidget {
  const _SignedOutBody({required this.l10n});

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
            Icon(Icons.account_circle_outlined,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(l10n.profileSignedOutTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.profileSignedOutBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.auth),
              icon: const Icon(Icons.login),
              label: Text(l10n.profileSignInCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInBody extends ConsumerWidget {
  const _SignedInBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    final displayName = (profile?.displayName?.isNotEmpty ?? false)
        ? profile!.displayName!
        : (user?.email ?? l10n.profileDefaultName);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        // Header: avatar, name/email/bio, edit-profile.
        Row(
          children: <Widget>[
            _ProfileAvatar(
                path: ref.watch(avatarPathProvider).valueOrNull, radius: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(displayName, style: theme.textTheme.titleLarge),
                  if (user?.email != null)
                    Text(
                      user!.email!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.profileEditProfile,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppRoutes.editProfile),
            ),
          ],
        ),
        Builder(builder: (context) {
          final bio = ref.watch(profileBioProvider).valueOrNull ?? '';
          if (bio.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(bio, style: theme.textTheme.bodyMedium),
          );
        }),
        const SizedBox(height: 24),
        // Local stats; avg WPM and badges stay placeholders until session
        // tracking / badges land.
        Builder(builder: (context) {
          final stats = ref.watch(readingStatsProvider).valueOrNull;
          // Plain two-card row — no grid dead space.
          return Row(
            children: <Widget>[
              Expanded(
                child: _StatCard(
                  label: l10n.profileStatsBooksRead,
                  value: stats?.booksRead.toString() ?? '—',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: l10n.profileStatsCurrentBooks,
                  value: stats?.currentBooks.toString() ?? '—',
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 16),
        _CurrentlyReadingSection(l10n: l10n),
        _FavoritesShowcase(l10n: l10n),
        _SyncSection(l10n: l10n),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(l10n.settingsTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.settings),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          icon: const Icon(Icons.logout),
          label: Text(l10n.profileSignOut),
        ),
      ],
    );
  }
}

/// Manual sync entry point. Shows pending count + last result; disabled with a
/// clear message when the backend is not configured.
class _SyncSection extends ConsumerWidget {
  const _SyncSection({required this.l10n});

  final AppLocalizations l10n;

  String _statusText(SyncUiState state, int pending) {
    return switch (state) {
      SyncRunning() => l10n.syncRunning,
      SyncSuccess(:final result) =>
        result.processed == 0 ? l10n.syncUpToDate : l10n.syncSucceeded(result.succeeded),
      SyncFailure(:final failure) => failure is UnauthorizedFailure
          ? l10n.syncSignInRequired
          : l10n.syncFailed,
      SyncIdle() =>
        pending == 0 ? l10n.syncUpToDate : l10n.syncPending(pending),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(backendConfiguredProvider);
    if (!configured) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(l10n.syncSectionTitle),
          subtitle: Text(l10n.syncBackendNotConfigured),
        ),
      );
    }

    final state = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final running = state is SyncRunning;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.cloud_sync_outlined),
        title: Text(l10n.syncSectionTitle),
        subtitle: Text(_statusText(state, pending)),
        trailing: running
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: () =>
                    ref.read(syncControllerProvider.notifier).syncNow(),
                child: Text(l10n.syncNow),
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(value, style: theme.textTheme.headlineSmall),
            Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.path, required this.radius});

  final String? path;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (path != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(path!)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Icon(Icons.person, size: radius, color: scheme.onSurfaceVariant),
    );
  }
}

/// The book currently being read (most recently opened "reading" entry),
/// with its cover — tapping resumes it.
class _CurrentlyReadingSection extends ConsumerWidget {
  const _CurrentlyReadingSection({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final books = ref.watch(myBooksProvider).valueOrNull ?? const <LibraryBook>[];
    final reading = books
        .where((b) => b.status == BookShelfStatus.reading && b.hasLocalFile)
        .toList()
      ..sort((a, b) => (b.lastOpenedAt ?? DateTime(0))
          .compareTo(a.lastOpenedAt ?? DateTime(0)));
    if (reading.isEmpty) return const SizedBox.shrink();
    final book = reading.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.profileCurrentlyReading, style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(AppRoutes.reader(book.id)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    BookCover(coverPath: book.coverPath, width: 48, height: 68),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall),
                          if (book.authorDisplay.isNotEmpty)
                            Text(book.authorDisplay,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: (book.percent / 100).clamp(0.0, 1.0),
                            semanticsLabel: l10n.readerProgressLabel,
                            semanticsValue: '${book.percent.round()}%',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${book.percent.round()}%',
                        style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal showcase of the user's favourite books (covers), shown between
/// the currently-reading card and the sync section.
class _FavoritesShowcase extends ConsumerWidget {
  const _FavoritesShowcase({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favorites = ref.watch(favoriteBooksProvider);
    if (favorites.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.profileFavorites, style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: favorites.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final book = favorites[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.push(AppRoutes.reader(book.id)),
                  child: BookCover(
                      coverPath: book.coverPath, width: 82, height: 124),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
