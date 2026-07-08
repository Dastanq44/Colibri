import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/widgets/large_title_scaffold.dart';
import '../../../core/errors/failures.dart';
import '../../auth/application/auth_providers.dart';
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

    return LargeTitleScaffold(
      title: l10n.profileTitle,
      actions: <Widget>[
        IconButton(
          tooltip: l10n.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push(AppRoutes.settings),
        ),
      ],
      slivers: <Widget>[
        signedIn
            ? _SignedInBody(l10n: l10n)
            : SliverFillRemaining(
                hasScrollBody: false,
                child: _SignedOutBody(l10n: l10n),
              ),
      ],
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

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditNameDialog(l10n: l10n, initialName: current),
    );
    if (newName == null || newName.isEmpty) return;
    // The widget may have been disposed while the dialog was open (e.g. the
    // session ended); `ref` must not be used after that.
    if (!context.mounted) return;

    final result =
        await ref.read(profileRepositoryProvider).updateDisplayName(newName);
    if (!context.mounted) return;
    result.when(
      ok: (_) => ref.invalidate(currentProfileProvider),
      err: (failure) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    final displayName = (profile?.displayName?.isNotEmpty ?? false)
        ? profile!.displayName!
        : (user?.email ?? l10n.profileDefaultName);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverList.list(
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              const CircleAvatar(
                radius: 28,
                child: Icon(Icons.person, size: 32),
              ),
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
                tooltip: l10n.profileEditName,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    _editName(context, ref, profile?.displayName ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Local stats; avg WPM and badges stay placeholders until session
          // tracking / badges land.
          Builder(builder: (context) {
            final stats = ref.watch(readingStatsProvider).valueOrNull;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: <Widget>[
                _StatCard(
                  label: l10n.profileStatsBooksRead,
                  value: stats?.booksRead.toString() ?? '—',
                ),
                _StatCard(
                  label: l10n.profileStatsCurrentBooks,
                  value: stats?.currentBooks.toString() ?? '—',
                ),
                _StatCard(
                  label: l10n.profileStatsAvgWpm,
                  value: stats?.avgWpm?.toString() ?? '—',
                ),
                _StatCard(label: l10n.profileStatsBadges, value: '—'),
              ],
            );
          }),
          const SizedBox(height: 24),
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
      ),
    );
  }
}

/// Edit-name dialog. Owns its [TextEditingController] so it is disposed with
/// the route (after the exit animation), not while the dialog is still closing.
class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.l10n, required this.initialName});

  final AppLocalizations l10n;
  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.profileEditName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.profileDisplayNameHint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.profileCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.profileSave),
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
      SyncSuccess(:final result) => result.processed == 0
          ? l10n.syncUpToDate
          : l10n.syncSucceeded(result.succeeded),
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
