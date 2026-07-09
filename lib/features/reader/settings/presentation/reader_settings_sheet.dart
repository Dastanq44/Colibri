import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../../../app/theme/reader_fonts.dart';
import '../../../../app/theme/reader_theme.dart';
import '../application/reader_settings_providers.dart';
import '../application/reading_presets_controller.dart';
import '../domain/reader_settings.dart';
import '../domain/reading_preset.dart';

/// Bottom-sheet panel for reader + fast-mode settings, themed by the chosen
/// reading palette. Every change writes to local settings immediately, is
/// reflected live, and updates the active preset's snapshot.
class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(readerSettingsRepositoryProvider);
    final settings = ref.watch(readerSettingsProvider).valueOrNull ??
        ReaderSettings.defaults();
    final fast = ref.watch(fastModeSettingsProvider);
    final palette = ReaderPalette.of(settings.theme);
    final label = TextStyle(color: palette.text);
    final body = TextStyle(color: palette.text, fontSize: 15);

    // Material (not a plain Container): ListTiles paint their ink on the
    // nearest Material, and it repaints live when the theme changes.
    return Material(
      color: palette.background,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Hand-drawn drag handle (the sheet paints its own background so
            // theme changes repaint live; the stock handle belongs to the host).
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.dim.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Pinned header so the close button stays reachable no matter how far
            // the (tall, scroll-controlled) settings list is scrolled.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.readerSettingsTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: palette.text),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.dialogClose,
                    color: palette.text,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(l10n.settingsPresets, style: label),
                    const SizedBox(height: 8),
                    _PresetsSection(
                        l10n: l10n, settings: settings, palette: palette),
                    const SizedBox(height: 16),
                    Text(l10n.settingsTheme, style: label),
                    const SizedBox(height: 8),
                    _SlidingSegments<ReaderThemeVariant>(
                      palette: palette,
                      groupValue: settings.theme,
                      onChanged: repo.setTheme,
                      options: <ReaderThemeVariant, String>{
                        ReaderThemeVariant.light: l10n.themeLight,
                        ReaderThemeVariant.sepia: l10n.themeSepia,
                        ReaderThemeVariant.dark: l10n.themeDark,
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.settingsExample,
                      style: TextStyle(color: palette.dim, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    // Live sample so theme/font/size/spacing changes are seen.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: palette.dim.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        "Great holes secretly are digged where earth's pores "
                        'ought to suffice, and things have learnt to walk that '
                        'ought to crawl.',
                        style: settings.fontFamily.applyTo(TextStyle(
                          fontSize: settings.fontSize.toDouble(),
                          height: settings.lineHeight,
                          letterSpacing: settings.letterSpacing,
                          color: palette.text,
                        )),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.settingsFontFamily, style: label),
                    const SizedBox(height: 8),
                    _SlidingSegments<ReaderFontFamily>(
                      palette: palette,
                      groupValue: settings.fontFamily,
                      onChanged: repo.setFontFamily,
                      options: <ReaderFontFamily, String>{
                        ReaderFontFamily.system: l10n.fontFamilySystem,
                        ReaderFontFamily.serif: l10n.fontFamilySerif,
                        ReaderFontFamily.monospace: l10n.fontFamilyMonospace,
                      },
                    ),
                    const SizedBox(height: 8),
                    _StepperRow(
                      palette: palette,
                      label: l10n.settingsFontSize,
                      value: '${settings.fontSize}',
                      onDecrease: () => repo.setFontSize((settings.fontSize - 1)
                          .clamp(ReaderSettings.minFontSize,
                              ReaderSettings.maxFontSize)),
                      onIncrease: () => repo.setFontSize((settings.fontSize + 1)
                          .clamp(ReaderSettings.minFontSize,
                              ReaderSettings.maxFontSize)),
                    ),
                    _StepperRow(
                      palette: palette,
                      label: l10n.settingsLineHeight,
                      value: settings.lineHeight.toStringAsFixed(1),
                      onDecrease: () => repo.setLineHeight(
                          (settings.lineHeight - 0.1).clamp(
                              ReaderSettings.minLineHeight,
                              ReaderSettings.maxLineHeight)),
                      onIncrease: () => repo.setLineHeight(
                          (settings.lineHeight + 0.1).clamp(
                              ReaderSettings.minLineHeight,
                              ReaderSettings.maxLineHeight)),
                    ),
                    _StepperRow(
                      palette: palette,
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
                    Divider(
                        height: 24, color: palette.dim.withValues(alpha: 0.4)),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.settingsPageAnimation, style: body),
                      value: settings.pageAnimationEnabled,
                      onChanged: repo.setPageAnimationEnabled,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.settingsHaptics, style: body),
                      value: settings.hapticsEnabled,
                      onChanged: repo.setHapticsEnabled,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.settingsReducedMotion, style: body),
                      value: settings.reducedMotion,
                      onChanged: repo.setReducedMotion,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.readerModeLock, style: body),
                      value: settings.modeLockEnabled,
                      // Same haptic as the reader's bottom-bar lock button
                      // (TASK-1007: mode lock toggle).
                      onChanged: (value) {
                        if (settings.hapticsEnabled) {
                          unawaited(HapticFeedback.selectionClick());
                        }
                        repo.setModeLock(value);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.settingsSpeedLock, style: body),
                      value: settings.speedLockEnabled,
                      onChanged: repo.setSpeedLock,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.settingsShowAdjacent, style: body),
                      value: fast.showAdjacentContext,
                      onChanged: repo.setShowAdjacentContext,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.settingsNaturalPauses, style: body),
                      subtitle: Text(
                        l10n.settingsNaturalPausesHint,
                        style: TextStyle(color: palette.dim, fontSize: 13),
                      ),
                      value: fast.naturalPausesEnabled,
                      onChanged: repo.setNaturalPauses,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// User presets as capsules, three per row (max 6 -> two rows), with +/-
/// controls. The active preset is highlighted with a neutral fill.
class _PresetsSection extends ConsumerWidget {
  const _PresetsSection({
    required this.l10n,
    required this.settings,
    required this.palette,
  });

  final AppLocalizations l10n;
  final ReaderSettings settings;
  final ReaderPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(readingPresetsProvider).valueOrNull;
    final controller = ref.read(readingPresetsProvider.notifier);
    final presets = state?.presets ?? const <ReadingPreset>[];
    final activeId = state?.activeId;
    final isDark = palette.variant == ReaderThemeVariant.dark;
    final highlight = isDark ? const Color(0xFF636366) : Colors.white;

    Widget capsule({
      required Widget child,
      required VoidCallback? onTap,
      bool active = false,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? highlight
                : palette.dim.withValues(alpha: isDark ? 0.25 : 0.15),
            borderRadius: BorderRadius.circular(18),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      // Three capsules per row with 8px gaps.
      final width = (constraints.maxWidth - 16) / 3;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final preset in presets)
            SizedBox(
              width: width,
              child: capsule(
                active: preset.id == activeId,
                onTap: () => controller.select(preset.id),
                child: Text(
                  l10n.presetName(preset.letter),
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: preset.id == activeId
                        ? FontWeight.w600
                        : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          if (presets.length < kMaxReadingPresets)
            SizedBox(
              width: 44,
              child: capsule(
                onTap: () => controller.addPreset(settings),
                child: Icon(Icons.add, size: 18, color: palette.text),
              ),
            ),
          if (presets.length > 1)
            SizedBox(
              width: 44,
              child: capsule(
                onTap: controller.removeActive,
                child: Icon(Icons.remove, size: 18, color: palette.text),
              ),
            ),
        ],
      );
    });
  }
}

/// Fixed segmented control in a neutral style: grey track, WHITE sliding
/// thumb (never the accent colour) with a glide animation. All segments
/// visible and equal width.
class _SlidingSegments<T extends Object> extends StatelessWidget {
  const _SlidingSegments({
    required this.palette,
    required this.groupValue,
    required this.onChanged,
    required this.options,
  });

  final ReaderPalette palette;
  final T groupValue;
  final ValueChanged<T> onChanged;
  final Map<T, String> options;

  @override
  Widget build(BuildContext context) {
    final isDark = palette.variant == ReaderThemeVariant.dark;
    final keys = options.keys.toList();
    final index = keys.indexOf(groupValue).clamp(0, keys.length - 1);
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.dim.withValues(alpha: isDark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final segWidth = constraints.maxWidth / keys.length;
        return Stack(
          children: <Widget>[
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment(
                keys.length == 1 ? 0 : -1 + 2 * index / (keys.length - 1),
                0,
              ),
              child: Container(
                width: segWidth,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF636366) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: <Widget>[
                for (final key in keys)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => onChanged(key),
                      child: Center(
                        child: Text(
                          options[key]!,
                          style: TextStyle(color: palette.text, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.palette,
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final ReaderPalette palette;
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
          Expanded(child: Text(label, style: TextStyle(color: palette.text))),
          IconButton(
            tooltip: l10n.settingsDecrease,
            color: palette.text,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onDecrease,
          ),
          SizedBox(
            width: 64,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.text),
            ),
          ),
          IconButton(
            tooltip: l10n.settingsIncrease,
            color: palette.text,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}
