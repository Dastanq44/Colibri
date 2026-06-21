import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder settings screen. Real settings UI is built in Phase 4 and
/// connected to local reader settings in Phase 10.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.settingsTitle,
      subtitle: l10n.comingSoon,
      icon: Icons.settings_outlined,
    );
  }
}
