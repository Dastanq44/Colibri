import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../auth/application/auth_providers.dart';
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

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileEditName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.profileDisplayNameHint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.profileCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.profileSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty) return;

    final result =
        await ref.read(profileRepositoryProvider).updateDisplayName(newName);
    result.when(
      ok: (_) => ref.invalidate(currentProfileProvider),
      err: (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message)));
        }
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

    return ListView(
      padding: const EdgeInsets.all(16),
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
        // Placeholder stats (wired to real data in later phases)
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: <Widget>[
            _StatCard(label: l10n.profileStatsBooksRead, value: '—'),
            _StatCard(label: l10n.profileStatsCurrentBooks, value: '—'),
            _StatCard(label: l10n.profileStatsAvgWpm, value: '—'),
            _StatCard(label: l10n.profileStatsBadges, value: '—'),
          ],
        ),
        const SizedBox(height: 24),
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
