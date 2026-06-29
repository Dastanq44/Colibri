/// Playback state of the fast-mode engine.
enum FastModePlaybackState {
  idle,
  ready,
  playing,
  paused,
  completed,
  error,
}

/// Why fast mode is unavailable (used to pick a localized message).
enum FastModeError {
  /// The book format does not support fast mode (e.g. PDF/EPUB for now).
  unavailable,

  /// The book has no readable text to tokenize.
  noText,
}
