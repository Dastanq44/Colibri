import 'package:colibri/features/reader/fast_mode/application/fast_mode_engine.dart';
import 'package:colibri/features/reader/fast_mode/domain/fast_mode_playback_state.dart';
import 'package:colibri/features/reader/fast_mode/domain/fast_mode_settings.dart';
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

  test('play after completion restarts from the first token', () {
    final e = _engine();
    e.loadTokens(_tokens(2));
    e.play();
    e.goToNextToken(); // -> index 1 (last)
    e.goToNextToken(); // at last -> completed
    expect(e.state.playback, FastModePlaybackState.completed);

    e.play();
    expect(e.state.playback, FastModePlaybackState.playing);
    expect(e.state.currentTokenIndex, 0);
    expect(e.state.isPlaying, isTrue); // no misleading 'Paused' feedback
  });

  test('togglePlayPause from completed restarts playback', () {
    final e = _engine();
    e.loadTokens(_tokens(2));
    e.play();
    e.goToNextToken();
    e.goToNextToken(); // completed
    e.togglePlayPause(); // center tap at end of book
    expect(e.state.isPlaying, isTrue);
    expect(e.state.currentTokenIndex, 0);
  });

  test('dispose does not persist the position', () {
    var saves = 0;
    final e = FastModeEngine(onSavePosition: (_, __) async => saves++);
    e.loadTokens(_tokens(3), startIndex: 1);
    final before = saves;
    e.dispose();
    expect(saves, before);
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

  test('speed lock prevents WPM changes', () {
    final e = _engine();
    e.loadTokens(_tokens(3));
    e.applySettings(
      FastModeSettings.defaults().copyWith(speedLockEnabled: true),
    );
    final before = e.state.wpm;
    expect(e.increaseWpm(), isFalse);
    expect(e.state.wpm, before);
  });

  test('WPM change returns false at the boundary (no spurious feedback)', () {
    final e = _engine();
    e.loadTokens(_tokens(3));
    e.setWpm(700);
    expect(e.increaseWpm(), isFalse);
    expect(e.state.wpm, 700);
  });

  test('applySettings snaps WPM to the new default until the user changes it',
      () {
    final e = _engine();
    e.loadTokens(_tokens(3)); // default wpm 275

    e.applySettings(FastModeSettings.defaults().copyWith(wpm: 350));
    expect(e.state.wpm, 350);

    e.increaseWpm(); // user touches WPM (-> 375)
    e.applySettings(FastModeSettings.defaults().copyWith(wpm: 200));
    expect(e.state.wpm, 375); // keeps the user's value
  });

  test('show adjacent context comes from settings', () {
    final e = _engine();
    e.loadTokens(_tokens(3));
    expect(e.state.settings.showAdjacentContext, isTrue);
    e.applySettings(
      FastModeSettings.defaults().copyWith(showAdjacentContext: false),
    );
    expect(e.state.settings.showAdjacentContext, isFalse);
  });
}
