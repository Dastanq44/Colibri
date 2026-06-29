import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../application/reader_providers.dart';
import '../../domain/reader_locator.dart';
import '../../domain/reader_mode.dart';
import '../data/fast_mode_tokenizer.dart';
import '../domain/fast_mode_playback_state.dart';
import '../domain/fast_token.dart';
import 'fast_mode_engine.dart';

final fastModeTokenizerProvider =
    Provider<FastModeTokenizer>((ref) => const FastModeTokenizer());

/// One [FastModeEngine] per book. Created lazily when fast mode is first shown;
/// loads + tokenizes the document and resumes from saved progress. Kept alive
/// (not auto-disposed) so rotating between portrait/landscape is instant.
final fastModeEngineProvider = Provider.family<FastModeEngine, String>(
  (ref, bookId) {
    final repo = ref.read(readerRepositoryProvider);
    final engine = FastModeEngine(
      onSavePosition: (token, percent) async {
        await repo.saveLocator(
          bookId,
          ReaderLocator(
            locatorType: 'txt_offset',
            locatorValue: token.startOffset.toString(),
            paragraphIndex: token.paragraphIndex,
            tokenIndex: token.tokenIndex,
            percent: percent,
          ),
          mode: ReaderMode.fast,
        );
      },
    );
    ref.onDispose(engine.dispose);
    _loadFastMode(ref, bookId, engine);
    return engine;
  },
);

Future<void> _loadFastMode(Ref ref, String bookId, FastModeEngine engine) async {
  final repo = ref.read(readerRepositoryProvider);
  switch (await repo.openBook(bookId)) {
    case Err():
      engine.fail(FastModeError.unavailable);
    case Ok(value: final doc):
      if (doc.format != 'txt') {
        engine.fail(FastModeError.unavailable);
        return;
      }
      final tokens = ref
          .read(fastModeTokenizerProvider)
          .tokenize(bookId: bookId, text: doc.fullText);
      if (tokens.isEmpty) {
        engine.fail(FastModeError.noText);
        return;
      }
      var startIndex = 0;
      if (await repo.getSavedLocator(bookId)
          case Ok(value: final ReaderLocator loc)) {
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
