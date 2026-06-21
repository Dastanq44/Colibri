import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder profile screen. Real profile UI is built in Phase 3.
/// Exposes a Settings entry point as specified by the route plan.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.profileTitle,
      subtitle: l10n.comingSoon,
      icon: Icons.person_outline,
      child: OutlinedButton.icon(
        onPressed: () => context.push(AppRoutes.settings),
        icon: const Icon(Icons.settings_outlined),
        label: Text(l10n.settingsTitle),
      ),
    );
  }
}
