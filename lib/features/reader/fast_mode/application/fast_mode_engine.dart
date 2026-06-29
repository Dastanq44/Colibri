import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/fast_mode_playback_state.dart';
import '../domain/fast_mode_settings.dart';
import '../domain/fast_mode_state.dart';
import '../domain/fast_token.dart';

/// UI-independent fast-mode engine. Holds tokens + playback and advances on a
/// WPM-driven timer. Exposes state via [ChangeNotifier] so any view (or test)
/// can observe it; persistence is delegated through [onSavePosition].
///
/// Tests can drive advancement deterministically by calling [goToNextToken]
/// directly instead of waiting on the timer.
class FastModeEngine extends ChangeNotifier {
  FastModeEngine({
    FastModeSettings? settings,
    this.onSavePosition,
  }) : _state = FastModeState.initial(settings ?? FastModeSettings.defaults());

  /// Called to persist the current token position (token + percent).
  final Future<void> Function(FastToken token, double percent)? onSavePosition;

  FastModeState _state;
  FastModeState get state => _state;

  Timer? _timer;

  void _set(FastModeState next) {
    _state = next;
    notifyListeners();
  }

  /// Marks fast mode unavailable / lacking text.
  void fail(FastModeError reason) {
    _stopTimer();
    _set(_state.copyWith(
      playback: FastModePlaybackState.error,
      errorReason: reason,
    ));
  }

  /// Loads tokens and becomes [FastModePlaybackState.ready] (paused), resuming
  /// at [startIndex]. Empty tokens become an error.
  void loadTokens(List<FastToken> tokens, {int startIndex = 0}) {
    _stopTimer();
    if (tokens.isEmpty) {
      _set(_state.copyWith(
        tokens: const <FastToken>[],
        currentTokenIndex: 0,
        playback: FastModePlaybackState.error,
        errorReason: FastModeError.noText,
      ));
      return;
    }
    _set(_state.copyWith(
      tokens: tokens,
      currentTokenIndex: startIndex.clamp(0, tokens.length - 1),
      playback: FastModePlaybackState.ready,
      clearError: true,
    ));
  }

  void play() {
    if (_state.tokens.isEmpty ||
        _state.playback == FastModePlaybackState.error) {
      return;
    }
    if (_state.playback == FastModePlaybackState.completed) return;
    _set(_state.copyWith(playback: FastModePlaybackState.playing));
    _startTimer();
  }

  void pause() {
    _stopTimer();
    if (_state.playback == FastModePlaybackState.playing ||
        _state.playback == FastModePlaybackState.ready) {
      _set(_state.copyWith(playback: FastModePlaybackState.paused));
    }
    _save();
  }

  void togglePlayPause() => _state.isPlaying ? pause() : play();

  void increaseWpm() => _changeWpm(_state.wpm + _state.settings.step);

  void decreaseWpm() => _changeWpm(_state.wpm - _state.settings.step);

  void setWpm(int wpm) => _changeWpm(wpm);

  void _changeWpm(int wpm) {
    if (_state.settings.speedLockEnabled) return; // speed locked: ignore
    final clamped = wpm.clamp(_state.settings.minWpm, _state.settings.maxWpm);
    if (clamped == _state.wpm) return;
    _set(_state.copyWith(wpm: clamped));
    if (_state.isPlaying) _startTimer(); // apply new interval
  }

  void seekToTokenIndex(int index) {
    if (_state.tokens.isEmpty) return;
    final clamped = index.clamp(0, _state.tokens.length - 1);
    final playback = _state.playback == FastModePlaybackState.completed
        ? FastModePlaybackState.paused
        : _state.playback;
    _set(_state.copyWith(currentTokenIndex: clamped, playback: playback));
    _save();
  }

  /// Moves to the token at/after [offset] in the source text (used to resume
  /// fast mode from the normal reader's position).
  void seekToOffset(int offset) {
    if (_state.tokens.isEmpty) return;
    var index = _state.tokens.indexWhere((t) => t.startOffset >= offset);
    if (index < 0) index = _state.tokens.length - 1;
    seekToTokenIndex(index);
  }

  /// Advances one token (also what the play timer calls). Completes at the end.
  void goToNextToken() {
    if (_state.tokens.isEmpty) return;
    if (_state.currentTokenIndex >= _state.tokens.length - 1) {
      _stopTimer();
      _set(_state.copyWith(playback: FastModePlaybackState.completed));
      _save();
      return;
    }
    final nextIndex = _state.currentTokenIndex + 1;
    _set(_state.copyWith(currentTokenIndex: nextIndex));
    // Checkpoint periodically so progress isn't lost mid-playback.
    if (nextIndex % 20 == 0) _save();
  }

  void savePosition() => _save();

  /// Current token's source start offset (for handing off to the normal reader).
  int? get currentStartOffset => _state.currentToken?.startOffset;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: _state.millisecondsPerToken),
      (_) => goToNextToken(),
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _save() async {
    final token = _state.currentToken;
    final cb = onSavePosition;
    if (token != null && cb != null) {
      await cb(token, _state.progressPercent);
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
