import 'package:colibri/features/reader/fast_mode/application/fast_mode_engine.dart';
import 'package:colibri/features/reader/fast_mode/domain/fast_mode_playback_state.dart';
import 'package:colibri/features/reader/fast_mode/domain/fast_token.dart';
import 'package:flutter_test/flutter_test.dart';

List<FastToken> _tokens(int n) => List<FastToken>.generate(
      n,
      (i) => FastToken(
        bookId: 'b1',
        chapterIndex: 0,
        paragraphIndex: 0,
        tokenIndex: i,
        rawText: 'w$i',
        normalizedText: 'w$i',
        startOffset: i * 5,
        endOffset: i * 5 + 3,
      ),
    );

FastModeEngine _engine({
  Future<void> Function(FastToken, double)? onSave,
}) {
  final engine = FastModeEngine(onSavePosition: onSave);
  addTearDown(engine.dispose);
  return engine;
}

void main() {
  test('loads ready (paused) at the start index', () {
    final e = _engine();
    e.loadTokens(_tokens(5), startIndex: 2);

    expect(e.state.playback, FastModePlaybackState.ready);
    expect(e.state.currentTokenIndex, 2);
    expect(e.state.isPlaying, isFalse);
  });

  test('play starts playing; goToNextToken advances', () {
    final e = _engine();
    e.loadTokens(_tokens(3));

    e.play();
    expect(e.state.playback, FastModePlaybackState.playing);

    e.goToNextToken();
    expect(e.state.currentTokenIndex, 1);
  });

  test('pause stops advancement', () {
    final e = _engine();
    e.loadTokens(_tokens(3));
    e.play();
    e.pause();

    expect(e.state.playback, FastModePlaybackState.paused);
    expect(e.state.isPlaying, isFalse);
  });

  test('reaching the last token completes', () {
    final e = _engine();
    e.loadTokens(_tokens(2));
    e.play();

    e.goToNextToken(); // -> index 1 (last)
    expect(e.state.currentTokenIndex, 1);
    e.goToNextToken(); // at last -> completed
    expect(e.state.playback, FastModePlaybackState.completed);
  });

  test('WPM respects 150–700 bounds and step', () {
    final e = _engine();
    e.loadTokens(_tokens(3));

    expect(e.state.wpm, 275);
    e.increaseWpm();
    expect(e.state.wpm, 300);
    e.setWpm(10000);
    expect(e.state.wpm, 700);
    e.setWpm(0);
    expect(e.state.wpm, 150);
    e.decreaseWpm(); // already at min
    expect(e.state.wpm, 150);
  });

  test('empty token list is handled safely', () {
    final e = _engine();
    e.loadTokens(<FastToken>[]);

    expect(e.state.playback, FastModePlaybackState.error);
    e.play(); // no-op
    e.goToNextToken(); // no crash
    expect(e.state.currentTokenIndex, 0);
  });

  test('seekToOffset maps to the first token at/after the offset', () {
    final e = _engine();
    e.loadTokens(_tokens(5)); // offsets 0,5,10,15,20
    e.seekToOffset(11);
    expect(e.state.currentTokenIndex, 3); // offset 15
  });

  test('onSavePosition is invoked on pause with the current token', () {
    FastToken? saved;
    final e = _engine(onSave: (t, _) async => saved = t);
    e.loadTokens(_tokens(4), startIndex: 1);
    e.pause();
    expect(saved?.tokenIndex, 1);
  });
}
