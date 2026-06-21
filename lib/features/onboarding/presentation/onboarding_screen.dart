import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Placeholder onboarding screen. Real onboarding flow is built in Phase 4.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.onboardingTitle,
      subtitle: l10n.comingSoon,
      icon: Icons.waving_hand_outlined,
    );
  }
}
