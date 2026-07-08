import 'fast_mode_playback_state.dart';
import 'fast_mode_settings.dart';
import 'fast_token.dart';

/// Immutable snapshot of the fast-mode engine.
class FastModeState {
  const FastModeState({
    required this.tokens,
    required this.currentTokenIndex,
    required this.wpm,
    required this.playback,
    required this.settings,
    this.errorReason,
  });

  factory FastModeState.initial(FastModeSettings settings) => FastModeState(
        tokens: const <FastToken>[],
        currentTokenIndex: 0,
        wpm: settings.wpm,
        playback: FastModePlaybackState.idle,
        settings: settings,
      );

  final List<FastToken> tokens;
  final int currentTokenIndex;
  final int wpm;
  final FastModePlaybackState playback;
  final FastModeSettings settings;
  final FastModeError? errorReason;

  FastToken? get currentToken =>
      (currentTokenIndex >= 0 && currentTokenIndex < tokens.length)
          ? tokens[currentTokenIndex]
          : null;

  FastToken? get previousToken =>
      currentTokenIndex > 0 ? tokens[currentTokenIndex - 1] : null;

  FastToken? get nextToken => currentTokenIndex < tokens.length - 1
      ? tokens[currentTokenIndex + 1]
      : null;

  /// Token at [delta] positions from the current one (negative = earlier),
  /// or null if out of range. Used to show a couple of context words per side.
  FastToken? tokenAt(int delta) {
    final i = currentTokenIndex + delta;
    return (i >= 0 && i < tokens.length) ? tokens[i] : null;
  }

  bool get isPlaying => playback == FastModePlaybackState.playing;
  bool get isLoading =>
      playback == FastModePlaybackState.idle && tokens.isEmpty;

  int get wordsRead => currentTokenIndex;

  double get progressPercent {
    if (tokens.isEmpty) return 0;
    if (tokens.length == 1) return 100;
    return (currentTokenIndex / (tokens.length - 1)) * 100;
  }

  /// Milliseconds a single word is displayed, from `60000 / wpm`.
  int get millisecondsPerToken => (60000 / wpm).round().clamp(1, 100000);

  FastModeState copyWith({
    List<FastToken>? tokens,
    int? currentTokenIndex,
    int? wpm,
    FastModePlaybackState? playback,
    FastModeSettings? settings,
    FastModeError? errorReason,
    bool clearError = false,
  }) {
    return FastModeState(
      tokens: tokens ?? this.tokens,
      currentTokenIndex: currentTokenIndex ?? this.currentTokenIndex,
      wpm: wpm ?? this.wpm,
      playback: playback ?? this.playback,
      settings: settings ?? this.settings,
      errorReason: clearError ? null : (errorReason ?? this.errorReason),
    );
  }
}
