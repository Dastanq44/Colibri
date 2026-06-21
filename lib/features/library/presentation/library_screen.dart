import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder "My Books" screen. Real library UI is built in Phase 4 and
/// wired to local/cloud data in Phase 5.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.libraryTitle,
      subtitle: l10n.comingSoon,
      icon: Icons.menu_book_outlined,
    );
  }
}
