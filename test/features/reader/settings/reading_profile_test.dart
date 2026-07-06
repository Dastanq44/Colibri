import 'package:colibri/app/theme/reader_fonts.dart';
import 'package:colibri/app/theme/reader_theme.dart';
import 'package:colibri/features/reader/settings/domain/reader_settings.dart';
import 'package:colibri/features/reader/settings/domain/reading_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderFontFamily', () {
    test('wire round-trips for every value', () {
      for (final family in ReaderFontFamily.values) {
        expect(ReaderFontFamily.fromWire(family.wire), family);
      }
    });

    test('unknown wire value falls back to system', () {
      expect(ReaderFontFamily.fromWire('comic-sans'), ReaderFontFamily.system);
    });

    test('system keeps the platform default font', () {
      expect(ReaderFontFamily.system.family, isNull);
      expect(ReaderFontFamily.system.fallback, isNull);

      const base = TextStyle(fontSize: 18);
      final applied = ReaderFontFamily.system.applyTo(base);
      expect(applied.fontFamily, isNull);
      expect(applied.fontFamilyFallback, isNull);
    });

    test('serif and monospace map to platform stacks with generic fallbacks',
        () {
      final serif = ReaderFontFamily.serif.applyTo(const TextStyle());
      expect(serif.fontFamily, 'Georgia');
      expect(serif.fontFamilyFallback, contains('serif'));

      final mono = ReaderFontFamily.monospace.applyTo(const TextStyle());
      expect(mono.fontFamily, 'Menlo');
      expect(mono.fontFamilyFallback, contains('monospace'));
    });

    test('applyTo preserves the base style', () {
      const base = TextStyle(fontSize: 18, height: 1.5, letterSpacing: 0.5);
      final applied = ReaderFontFamily.serif.applyTo(base);
      expect(applied.fontSize, 18);
      expect(applied.height, 1.5);
      expect(applied.letterSpacing, 0.5);
    });
  });

  group('ReadingProfilePreset', () {
    test('standard matches the reader defaults', () {
      final preset = ReadingProfilePreset.of(ReadingProfile.standard);
      final defaults = ReaderSettings.defaults();
      expect(preset.fontFamily, defaults.fontFamily);
      expect(preset.fontSize, defaults.fontSize);
      expect(preset.lineHeight, defaults.lineHeight);
      expect(preset.letterSpacing, defaults.letterSpacing);
      expect(preset.theme, isNull);
    });

    test('every preset stays within the settings UI bounds', () {
      for (final profile in ReadingProfile.values) {
        final preset = ReadingProfilePreset.of(profile);
        expect(preset.fontSize,
            inInclusiveRange(ReaderSettings.minFontSize, ReaderSettings.maxFontSize),
            reason: '$profile fontSize');
        expect(
            preset.lineHeight,
            inInclusiveRange(
                ReaderSettings.minLineHeight, ReaderSettings.maxLineHeight),
            reason: '$profile lineHeight');
        expect(
            preset.letterSpacing,
            inInclusiveRange(ReaderSettings.minLetterSpacing,
                ReaderSettings.maxLetterSpacing),
            reason: '$profile letterSpacing');
      }
    });

    test('high readability and dyslexia increase size and spacing', () {
      final standard = ReadingProfilePreset.of(ReadingProfile.standard);
      final readable = ReadingProfilePreset.of(ReadingProfile.highReadability);
      final dyslexia = ReadingProfilePreset.of(ReadingProfile.dyslexia);

      expect(readable.fontSize, greaterThan(standard.fontSize));
      expect(readable.lineHeight, greaterThan(standard.lineHeight));
      expect(readable.letterSpacing, greaterThan(standard.letterSpacing));

      expect(dyslexia.fontFamily, ReaderFontFamily.system); // sans/system
      expect(dyslexia.fontSize, greaterThan(readable.fontSize));
      expect(dyslexia.letterSpacing, greaterThan(readable.letterSpacing));
    });

    test('low vision uses near-max size and suggests the dark theme', () {
      final preset = ReadingProfilePreset.of(ReadingProfile.lowVision);
      expect(preset.fontSize, greaterThanOrEqualTo(28));
      expect(preset.lineHeight, greaterThanOrEqualTo(2.0));
      expect(preset.theme, ReaderThemeVariant.dark);
    });
  });
}
