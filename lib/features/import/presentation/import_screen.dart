import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder import screen. The real import pipeline (file picker, copy,
/// checksum, metadata, local record, optional upload) is built in Phase 6.
class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.importTitle,
      subtitle: l10n.comingSoon,
      icon: Icons.file_upload_outlined,
    );
  }
}
