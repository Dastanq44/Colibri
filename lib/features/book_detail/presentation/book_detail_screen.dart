import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder book detail screen. Real book detail UI is built in Phase 4 and
/// wired to data in Phase 5.
class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.bookDetailTitle,
      subtitle: l10n.bookIdLabel(bookId),
      icon: Icons.auto_stories_outlined,
    );
  }
}
