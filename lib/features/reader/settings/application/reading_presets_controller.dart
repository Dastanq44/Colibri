import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/local/database_providers.dart';
import '../domain/reader_settings.dart';
import '../domain/reading_preset.dart';
import 'reader_settings_providers.dart';

/// Presets + which one is active.
class ReadingPresetsState {
  const ReadingPresetsState({required this.presets, required this.activeId});

  final List<ReadingPreset> presets;
  final String activeId;

  ReadingPreset? get active {
    for (final p in presets) {
      if (p.id == activeId) return p;
    }
    return presets.isEmpty ? null : presets.first;
  }
}

const int kMaxReadingPresets = 6;
const String _lettersPool = 'ABCDEF';

/// User reading presets ("Profile A".."Profile F"). Selecting one applies its
/// visual settings; editing settings silently updates the active preset (they
/// are freely customizable, never locked). Stored in the key-value table so
/// no schema migration is needed; the active choice is remembered.
final readingPresetsProvider =
    AsyncNotifierProvider<ReadingPresetsController, ReadingPresetsState>(
  ReadingPresetsController.new,
);

class ReadingPresetsController extends AsyncNotifier<ReadingPresetsState> {
  static const String _presetsKey = 'reading_presets';
  static const String _activeKey = 'reading_preset_active';

  @override
  Future<ReadingPresetsState> build() async {
    final dao = ref.read(appDatabaseProvider).keyValueDao;
    final raw = await dao.getValue(_presetsKey);
    var presets = <ReadingPreset>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        presets = ReadingPreset.decodeList(raw);
      } catch (_) {
        presets = <ReadingPreset>[];
      }
    }
    // First run: seed "Profile A" from the current settings.
    if (presets.isEmpty) {
      // One-shot read (never the stream's .first — the first emission can be
      // arbitrarily late); the settings listener below re-syncs the snapshot
      // if settings change afterwards.
      final settings =
          await ref.read(readerSettingsRepositoryProvider).getReaderSettings();
      presets = <ReadingPreset>[_newPreset('A', settings)];
      await dao.setValue(_presetsKey, ReadingPreset.encodeList(presets));
    }
    var activeId = await dao.getValue(_activeKey) ?? '';
    if (!presets.any((p) => p.id == activeId)) activeId = presets.first.id;

    // Editing any visual setting updates the active preset's snapshot, so
    // presets stay freely customizable without an explicit "save".
    ref.listen(readerSettingsProvider, (_, next) {
      final settings = next.valueOrNull;
      if (settings != null) _syncActive(settings);
    });

    return ReadingPresetsState(presets: presets, activeId: activeId);
  }

  ReadingPreset _newPreset(String letter, ReaderSettings settings) =>
      ReadingPreset(
        id: 'preset_$letter',
        letter: letter,
        theme: settings.theme,
        fontFamily: settings.fontFamily,
        fontSize: settings.fontSize,
        lineHeight: settings.lineHeight,
        letterSpacing: settings.letterSpacing,
      );

  Future<void> _persist(ReadingPresetsState next) async {
    state = AsyncData(next);
    final dao = ref.read(appDatabaseProvider).keyValueDao;
    await dao.setValue(_presetsKey, ReadingPreset.encodeList(next.presets));
    await dao.setValue(_activeKey, next.activeId);
  }

  /// Applies [preset]'s visual settings and remembers it as active.
  Future<void> select(String presetId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    ReadingPreset? preset;
    for (final p in current.presets) {
      if (p.id == presetId) preset = p;
    }
    if (preset == null) return;
    await _persist(
      ReadingPresetsState(presets: current.presets, activeId: presetId),
    );
    final repo = ref.read(readerSettingsRepositoryProvider);
    await repo.setTheme(preset.theme);
    await repo.setFontFamily(preset.fontFamily);
    await repo.setFontSize(preset.fontSize);
    await repo.setLineHeight(preset.lineHeight);
    await repo.setLetterSpacing(preset.letterSpacing);
  }

  /// Creates a new preset (first unused letter) from the current settings and
  /// makes it active. No-op at [kMaxReadingPresets].
  Future<void> addPreset(ReaderSettings settings) async {
    final current = state.valueOrNull;
    if (current == null || current.presets.length >= kMaxReadingPresets) {
      return;
    }
    final used = <String>{for (final p in current.presets) p.letter};
    final letter = _lettersPool.split('').firstWhere(
          (l) => !used.contains(l),
          orElse: () => '?',
        );
    if (letter == '?') return;
    final preset = _newPreset(letter, settings);
    await _persist(ReadingPresetsState(
      presets: <ReadingPreset>[...current.presets, preset],
      activeId: preset.id,
    ));
  }

  /// Removes the active preset (kept only when more than one exists); the
  /// remaining presets keep their names. The first remaining preset becomes
  /// active and its settings are applied.
  Future<void> removeActive() async {
    final current = state.valueOrNull;
    if (current == null || current.presets.length <= 1) return;
    final remaining =
        current.presets.where((p) => p.id != current.activeId).toList();
    await _persist(ReadingPresetsState(
      presets: remaining,
      activeId: remaining.first.id,
    ));
    await select(remaining.first.id);
  }

  /// Writes the current settings into the active preset when they differ.
  Future<void> _syncActive(ReaderSettings settings) async {
    final current = state.valueOrNull;
    final active = current?.active;
    if (current == null || active == null || active.matches(settings)) return;
    final updated = <ReadingPreset>[
      for (final p in current.presets)
        p.id == active.id ? p.withSettings(settings) : p,
    ];
    await _persist(
      ReadingPresetsState(presets: updated, activeId: current.activeId),
    );
  }
}
