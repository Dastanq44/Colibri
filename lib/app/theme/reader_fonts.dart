import 'package:flutter/material.dart';

/// Reader font family choices (TASK-1001).
///
/// No font assets are bundled: each choice maps to a platform font stack via
/// [family] + [fallback], so iOS and Android each resolve the nearest
/// installed face (the stack always ends in a generic CSS-style family).
enum ReaderFontFamily {
  system,
  serif,
  monospace;

  /// Stored value (matches the `font_family` settings column). Same as [name].
  String get wire => name;

  static ReaderFontFamily fromWire(String value) =>
      ReaderFontFamily.values.firstWhere(
        (v) => v.name == value,
        orElse: () => ReaderFontFamily.system,
      );

  /// Primary platform family (null = keep the platform default).
  String? get family => switch (this) {
        ReaderFontFamily.system => null,
        ReaderFontFamily.serif => 'Georgia',
        ReaderFontFamily.monospace => 'Menlo',
      };

  /// Fallback stack for platforms missing [family].
  ///
  /// Android note: no 'Courier New' fallback — Android aliases it to Cutive
  /// Mono, which has no Cyrillic and would mix typefaces in Russian text.
  /// The generic 'monospace' resolves to a face with Cyrillic coverage.
  List<String>? get fallback => switch (this) {
        ReaderFontFamily.system => null,
        ReaderFontFamily.serif => const <String>['Times New Roman', 'serif'],
        ReaderFontFamily.monospace => const <String>['monospace'],
      };

  /// Applies this family's stack to [base] (no-op for [system]).
  TextStyle applyTo(TextStyle base) => this == ReaderFontFamily.system
      ? base
      : base.copyWith(fontFamily: family, fontFamilyFallback: fallback);
}
