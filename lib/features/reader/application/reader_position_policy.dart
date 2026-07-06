import '../domain/reader_mode.dart';

/// Position-persistence policy shared by the reader screen. Kept as pure
/// functions so the invariants are unit-testable without widgets.

/// Issues exactly ONE save per exit/background event — the active mode's.
///
/// The inactive surface's position was already synced at the last mode
/// handoff; saving it too would overwrite fresh progress with a stale
/// position (e.g. the fast engine still holding the session's resume point
/// after the user paged ahead in portrait).
void saveActiveModePosition({
  required ReaderMode mode,
  required void Function() saveNormal,
  required void Function() saveFast,
}) {
  switch (mode) {
    case ReaderMode.normal:
      saveNormal();
    case ReaderMode.fast:
      saveFast();
  }
}

/// Whether a normal→fast handoff should re-seek the engine to the portrait
/// page start. Only when the engine's current token lies OUTSIDE the page's
/// [pageStart, pageEnd) range — otherwise the engine's finer-grained (token
/// level) position wins and rotating must not rewind it to the page start.
bool shouldSeekFastEngine({
  required int? engineOffset,
  required int pageStart,
  required int pageEnd,
}) =>
    engineOffset == null ||
    engineOffset < pageStart ||
    engineOffset >= pageEnd;
