import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder reader screen.
///
/// The real reader is the core of the product and is built across later
/// phases: normal portrait reader (Phase 7), fast-mode engine (Phase 8), and
/// landscape fast-mode UI + orientation switching (Phase 9). No reader,
/// orientation, or fast-mode logic exists yet.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.readerTitle,
      subtitle: l10n.bookIdLabel(bookId),
      icon: Icons.chrome_reader_mode_outlined,
    );
  }
}
