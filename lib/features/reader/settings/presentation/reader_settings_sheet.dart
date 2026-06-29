import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../../../app/theme/reader_theme.dart';
import '../application/reader_settings_providers.dart';
import '../domain/reader_settings.dart';

/// Bottom-sheet panel for reader + fast-mode settings. Every change writes to
/// local settings immediately and is reflected live (the sheet watches the
/// same providers the reader does).
class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(readerSettingsRepositoryProvider);
    final settings =
        ref.watch(readerSettingsProvider).valueOrNull ?? ReaderSettings.defaults();
    final fast = ref.watch(fastModeSettingsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l10n.readerSettingsTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(l10n.settingsTheme),
            const SizedBox(height: 8),
            SegmentedButton<ReaderThemeVariant>(
              segments: <ButtonSegment<ReaderThemeVariant>>[
                ButtonSegment(
                    value: ReaderThemeVariant.light, label: Text(l10n.themeLight)),
                ButtonSegment(
                    value: ReaderThemeVariant.sepia, label: Text(l10n.themeSepia)),
                ButtonSegment(
                    value: ReaderThemeVariant.dark, label: Text(l10n.themeDark)),
              ],
              selected: <ReaderThemeVariant>{settings.theme},
              onSelectionChanged: (s) => repo.setTheme(s.first),
            ),
            const SizedBox(height: 8),
            _StepperRow(
              label: l10n.settingsFontSize,
              value: '${settings.fontSize}',
              onDecrease: () => repo.setFontSize((settings.fontSize - 1)
                  .clamp(ReaderSettings.minFontSize, ReaderSettings.maxFontSize)),
              onIncrease: () => repo.setFontSize((settings.fontSize + 1)
                  .clamp(ReaderSettings.minFontSize, ReaderSettings.maxFontSize)),
            ),
            _StepperRow(
              label: l10n.settingsLineHeight,
              value: settings.lineHeight.toStringAsFixed(1),
              onDecrease: () => repo.setLineHeight((settings.lineHeight - 0.1).clamp(
                  ReaderSettings.minLineHeight, ReaderSettings.maxLineHeight)),
              onIncrease: () => repo.setLineHeight((settings.lineHeight + 0.1).clamp(
                  ReaderSettings.minLineHeight, ReaderSettings.maxLineHeight)),
            ),
            _StepperRow(
              label: l10n.settingsLetterSpacing,
              value: settings.letterSpacing.toStringAsFixed(1),
              onDecrease: () => repo.setLetterSpacing(
                  (settings.letterSpacing - 0.1).clamp(
                      ReaderSettings.minLetterSpacing,
                      ReaderSettings.maxLetterSpacing)),
              onIncrease: () => repo.setLetterSpacing(
                  (settings.letterSpacing + 0.1).clamp(
                      ReaderSettings.minLetterSpacing,
                      ReaderSettings.maxLetterSpacing)),
            ),
            _StepperRow(
              label: l10n.settingsDefaultWpm,
              value: '${fast.wpm} ${l10n.wpm}',
              onDecrease: () => repo.setDefaultWpm(
                  (fast.wpm - fast.step).clamp(fast.minWpm, fast.maxWpm)),
              onIncrease: () => repo.setDefaultWpm(
                  (fast.wpm + fast.step).clamp(fast.minWpm, fast.maxWpm)),
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.readerModeLock),
              value: settings.modeLockEnabled,
              onChanged: repo.setModeLock,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsSpeedLock),
              value: settings.speedLockEnabled,
              onChanged: repo.setSpeedLock,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsShowAdjacent),
              value: fast.showAdjacentContext,
              onChanged: repo.setShowAdjacentContext,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final String value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          IconButton(
            tooltip: l10n.settingsDecrease,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onDecrease,
          ),
          SizedBox(
            width: 64,
            child: Text(value, textAlign: TextAlign.center),
          ),
          IconButton(
            tooltip: l10n.settingsIncrease,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}
