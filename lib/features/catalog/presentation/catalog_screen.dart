import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder catalog screen. Real catalog UI is built in Phase 4 and wired
/// to data in Phase 5.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.catalogTitle,
      subtitle: l10n.comingSoon,
      icon: Icons.explore_outlined,
    );
  }
}
