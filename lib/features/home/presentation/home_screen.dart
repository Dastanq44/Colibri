import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';

/// Placeholder home screen.
///
/// The real Home (Continue Reading, goals, recommendation rails, quick
/// actions) is built in Phase 4. For the foundation this screen doubles as a
/// developer navigation hub so every placeholder route is reachable while the
/// app shell is still empty.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.devNavHeader,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          _NavTile(
            icon: Icons.waving_hand_outlined,
            label: l10n.openOnboarding,
            onTap: () => context.push(AppRoutes.onboarding),
          ),
          _NavTile(
            icon: Icons.lock_outline,
            label: l10n.openAuth,
            onTap: () => context.push(AppRoutes.auth),
          ),
          _NavTile(
            icon: Icons.file_upload_outlined,
            label: l10n.openImport,
            onTap: () => context.push(AppRoutes.importBook),
          ),
          _NavTile(
            icon: Icons.settings_outlined,
            label: l10n.openSettings,
            onTap: () => context.push(AppRoutes.settings),
          ),
          _NavTile(
            icon: Icons.auto_stories_outlined,
            label: l10n.openSampleBook,
            onTap: () => context.push(AppRoutes.bookDetail('sample')),
          ),
          _NavTile(
            icon: Icons.chrome_reader_mode_outlined,
            label: l10n.openSampleReader,
            onTap: () => context.push(AppRoutes.reader('sample')),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
