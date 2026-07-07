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
    this.onWpmChanged,
  }) : _state = FastModeState.initial(settings ?? FastModeSettings.defaults());

  /// Called to persist the current token position (token + percent).
  final Future<void> Function(FastToken token, double percent)? onSavePosition;

  /// Called when the user changes WPM, so it persists globally (plan 8.3:
  /// "WPM is saved globally") and survives closing the book.
  final void Function(int wpm)? onWpmChanged;

  FastModeState _state;
  FastModeState get state => _state;

  Timer? _timer;

  /// Tracks whether the user has manually changed WPM, so applying persisted
  /// settings doesn't override an in-session choice.
  bool _wpmTouched = false;

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
    // Completed: restart from the first token (end of book is not a dead end).
    final index = _state.playback == FastModePlaybackState.completed
        ? 0
        : _state.currentTokenIndex;
    _set(_state.copyWith(
      currentTokenIndex: index,
      playback: FastModePlaybackState.playing,
    ));
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

  /// Returns `true` only if WPM actually changed (so the UI can avoid showing
  /// "+25 WPM" at the min/max boundary).
  bool increaseWpm() => _changeWpm(_state.wpm + _state.settings.step);

  bool decreaseWpm() => _changeWpm(_state.wpm - _state.settings.step);

  bool setWpm(int wpm) => _changeWpm(wpm);

  bool _changeWpm(int wpm) {
    if (_state.settings.speedLockEnabled) return false; // speed locked
    final clamped = wpm.clamp(_state.settings.minWpm, _state.settings.maxWpm);
    if (clamped == _state.wpm) return false;
    _wpmTouched = true;
    _set(_state.copyWith(wpm: clamped));
    onWpmChanged?.call(clamped);
    if (_state.isPlaying) _startTimer(); // apply new interval
    return true;
  }

  /// Applies persisted fast-mode settings (bounds, step, adjacent context,
  /// speed lock). Snaps WPM to the new default until the user changes it.
  void applySettings(FastModeSettings settings) {
    final base = _wpmTouched ? _state.wpm : settings.wpm;
    final wpm = base.clamp(settings.minWpm, settings.maxWpm);
    _set(_state.copyWith(settings: settings, wpm: wpm));
    if (_state.isPlaying) _startTimer();
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
