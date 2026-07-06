import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../application/reader_providers.dart';
import '../../domain/reader_locator.dart';
import '../../domain/reader_locator_types.dart';
import '../../domain/reader_mode.dart';
import '../../settings/application/reader_settings_providers.dart';
import '../data/fast_mode_tokenizer.dart';
import '../domain/fast_mode_playback_state.dart';
import '../domain/fast_mode_settings.dart';
import '../domain/fast_token.dart';
import 'fast_mode_engine.dart';

final fastModeTokenizerProvider =
    Provider<FastModeTokenizer>((ref) => const FastModeTokenizer());

/// One [FastModeEngine] per open book. **Auto-disposed**: the engine (and its
/// timer) is freed when the reader screen stops watching it. ReaderScreen keeps
/// it alive while open, so portrait/landscape switching stays instant.
final fastModeEngineProvider =
    Provider.autoDispose.family<FastModeEngine, String>((ref, bookId) {
  final repo = ref.read(readerRepositoryProvider);
  final engine = FastModeEngine(
    settings: ref.read(fastModeSettingsProvider),
    onSavePosition: (token, percent) async {
      await repo.saveLocator(
        bookId,
        ReaderLocator(
          locatorType: ReaderLocatorTypes.textOffset,
          locatorValue: token.startOffset.toString(),
          paragraphIndex: token.paragraphIndex,
          tokenIndex: token.tokenIndex,
          percent: percent,
        ),
        mode: ReaderMode.fast,
      );
    },
  );

  // Apply live settings changes (WPM bounds, adjacent context, speed lock).
  ref.listen<FastModeSettings>(fastModeSettingsProvider, (_, next) {
    engine.applySettings(next);
  });

  // _loadFastMode can outlive this element (book closed mid-load); the flag
  // lets it bail instead of touching the disposed engine or ref.
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    engine.dispose();
  });
  _loadFastMode(ref, bookId, engine, () => disposed);
  return engine;
});

Future<void> _loadFastMode(
  Ref ref,
  String bookId,
  FastModeEngine engine,
  bool Function() isDisposed,
) async {
  final repo = ref.read(readerRepositoryProvider);
  final opened = await repo.openBook(bookId);
  if (isDisposed()) return;
  switch (opened) {
    case Err():
      engine.fail(FastModeError.unavailable);
    case Ok(value: final doc):
      final tokens = ref
          .read(fastModeTokenizerProvider)
          .tokenize(bookId: bookId, text: doc.fullText);
      if (tokens.isEmpty) {
        engine.fail(FastModeError.noText);
        return;
      }
      var startIndex = 0;
      final saved = await repo.getSavedLocator(bookId);
      if (isDisposed()) return;
      if (saved case Ok(value: final ReaderLocator loc)) {
        startIndex = _resolveStartIndex(tokens, loc);
      }
      engine.loadTokens(tokens, startIndex: startIndex);
  }
}

int _resolveStartIndex(List<FastToken> tokens, ReaderLocator locator) {
  final ti = locator.tokenIndex;
  if (ti != null && ti >= 0 && ti < tokens.length) return ti;
  final offset = int.tryParse(locator.locatorValue) ?? 0;
  final idx = tokens.indexWhere((t) => t.startOffset >= offset);
  return idx < 0 ? tokens.length - 1 : idx;
}
