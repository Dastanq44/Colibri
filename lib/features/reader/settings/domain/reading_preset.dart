import 'dart:convert';

import '../../../../app/theme/reader_fonts.dart';
import '../../../../app/theme/reader_theme.dart';
import 'reader_settings.dart';

/// A user-created reading preset ("Profile A".."Profile F"): a snapshot of the
/// visual reading settings. Stored as JSON in the key-value table.
class ReadingPreset {
  const ReadingPreset({
    required this.id,
    required this.letter,
    required this.theme,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
  });

  final String id;

  /// Display letter A..F; survives removals (names never shift).
  final String letter;

  final ReaderThemeVariant theme;
  final ReaderFontFamily fontFamily;
  final int fontSize;
  final double lineHeight;
  final double letterSpacing;

  /// Snapshot of [settings]' visual values under an existing identity.
  ReadingPreset withSettings(ReaderSettings settings) => ReadingPreset(
        id: id,
        letter: letter,
        theme: settings.theme,
        fontFamily: settings.fontFamily,
        fontSize: settings.fontSize,
        lineHeight: settings.lineHeight,
        letterSpacing: settings.letterSpacing,
      );

  bool matches(ReaderSettings s) =>
      theme == s.theme &&
      fontFamily == s.fontFamily &&
      fontSize == s.fontSize &&
      lineHeight == s.lineHeight &&
      letterSpacing == s.letterSpacing;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'letter': letter,
        'theme': theme.wire,
        'fontFamily': fontFamily.wire,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'letterSpacing': letterSpacing,
      };

  static ReadingPreset fromJson(Map<String, Object?> json) => ReadingPreset(
        id: json['id']! as String,
        letter: json['letter']! as String,
        theme: ReaderThemeVariant.fromWire(json['theme']! as String),
        fontFamily: ReaderFontFamily.fromWire(json['fontFamily']! as String),
        fontSize: (json['fontSize']! as num).toInt(),
        lineHeight: (json['lineHeight']! as num).toDouble(),
        letterSpacing: (json['letterSpacing']! as num).toDouble(),
      );

  static String encodeList(List<ReadingPreset> presets) =>
      jsonEncode(<Object?>[for (final p in presets) p.toJson()]);

  static List<ReadingPreset> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return <ReadingPreset>[
      for (final e in list) ReadingPreset.fromJson((e as Map).cast()),
    ];
  }
}
