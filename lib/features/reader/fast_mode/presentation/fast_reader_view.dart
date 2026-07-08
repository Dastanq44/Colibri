import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../../../app/theme/reader_fonts.dart';
import '../../../../app/theme/reader_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/repositories/analytics_repository.dart';
import '../../settings/application/reader_settings_providers.dart';
import '../application/fast_mode_engine.dart';
import '../application/fast_mode_providers.dart';
import '../application/fast_word_scale_provider.dart';
import '../domain/fast_mode_playback_state.dart';
import '../domain/fast_mode_state.dart';

/// Landscape fast (RSVP) reader. Current word centred symmetrically with two
/// dimmed context words per side (floor-aligned), tap-left/center/right to
/// slow/pause/speed up, pinch to resize. Honors persisted fast settings.
class FastReaderView extends ConsumerStatefulWidget {
  const FastReaderView({
    super.key,
    required this.bookId,
    required this.modeLocked,
    required this.onToggleModeLock,
  });

  final String bookId;
  final bool modeLocked;
  final VoidCallback onToggleModeLock;

  @override
  ConsumerState<FastReaderView> createState() => _FastReaderViewState();
}

class _FastReaderViewState extends ConsumerState<FastReaderView> {
  String? _feedback;
  Timer? _feedbackTimer;
  FastModeEngine? _engine;
  FastModePlaybackState? _lastPlayback;

  // Pinch-to-zoom on the word size.
  double? _pinchBase;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _engine?.removeListener(_onEngineChanged);
    super.dispose();
  }

  void _haptic(Future<void> Function() feedback) {
    final enabled =
        ref.read(readerSettingsProvider).valueOrNull?.hapticsEnabled ?? false;
    if (enabled) unawaited(feedback());
  }

  void _onEngineChanged() {
    final playback = _engine?.state.playback;
    if (playback == FastModePlaybackState.completed &&
        _lastPlayback != FastModePlaybackState.completed) {
      _haptic(HapticFeedback.mediumImpact);
    }
    _lastPlayback = playback;
  }

  @override
  void didUpdateWidget(FastReaderView old) {
    super.didUpdateWidget(old);
    if (!old.modeLocked && widget.modeLocked) {
      _flash(AppLocalizations.of(context).fastModeLocked);
    }
  }

  void _flash(String text) {
    setState(() => _feedback = text);
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(AppConstants.speedFeedbackDuration, () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  void _decrease(FastModeEngine engine, AppLocalizations l10n) {
    if (engine.state.settings.speedLockEnabled) {
      _flash(l10n.fastSpeedLocked);
      return;
    }
    if (engine.decreaseWpm()) {
      _haptic(HapticFeedback.selectionClick);
      unawaited(ref.read(analyticsRepositoryProvider).logEvent(
          'wpm_changed', params: {'wpm': engine.state.wpm, 'delta': -1}));
      _flash('-${engine.state.settings.step} ${l10n.wpm}');
    }
  }

  void _increase(FastModeEngine engine, AppLocalizations l10n) {
    if (engine.state.settings.speedLockEnabled) {
      _flash(l10n.fastSpeedLocked);
      return;
    }
    if (engine.increaseWpm()) {
      _haptic(HapticFeedback.selectionClick);
      unawaited(ref.read(analyticsRepositoryProvider).logEvent(
          'wpm_changed', params: {'wpm': engine.state.wpm, 'delta': 1}));
      _flash('+${engine.state.settings.step} ${l10n.wpm}');
    }
  }

  void _toggle(FastModeEngine engine, AppLocalizations l10n) {
    engine.togglePlayPause();
    unawaited(ref.read(analyticsRepositoryProvider).logEvent(
        'pause_play_toggled', params: {'playing': engine.state.isPlaying}));
    if (!engine.state.isPlaying) _flash(l10n.fastPaused);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = ref.watch(fastModeEngineProvider(widget.bookId));
    if (!identical(_engine, engine)) {
      _engine?.removeListener(_onEngineChanged);
      _engine = engine;
      _lastPlayback = engine.state.playback;
      engine.addListener(_onEngineChanged);
    }
    final readerSettings = ref.watch(readerSettingsProvider).valueOrNull;
    final theme = readerSettings?.theme ?? ReaderThemeVariant.light;
    final fontFamily = readerSettings?.fontFamily ?? ReaderFontFamily.system;
    final palette = ReaderPalette.of(theme);
    final scale = ref.watch(fastWordScaleProvider).valueOrNull ?? 1.0;

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final s = engine.state;
        if (s.isLoading) {
          return Scaffold(
            backgroundColor: palette.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (s.playback == FastModePlaybackState.error) {
          final message = s.errorReason == FastModeError.noText
              ? l10n.fastNoText
              : l10n.fastUnavailable;
          return Scaffold(
            backgroundColor: palette.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.block_outlined, size: 56, color: palette.dim),
                    const SizedBox(height: 16),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.text)),
                  ],
                ),
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  // Pinch anywhere to resize the words; single taps fall
                  // through to the zones below.
                  child: GestureDetector(
                    onScaleStart: (_) =>
                        _pinchBase = ref.read(fastWordScaleProvider).valueOrNull,
                    onScaleUpdate: (d) {
                      if (d.pointerCount < 2) return;
                      final base = _pinchBase ?? scale;
                      ref
                          .read(fastWordScaleProvider.notifier)
                          .preview(base * d.scale);
                    },
                    onScaleEnd: (_) {
                      if (_pinchBase != null) {
                        _pinchBase = null;
                        unawaited(
                            ref.read(fastWordScaleProvider.notifier).commit());
                      }
                    },
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Semantics(
                                  label: l10n.fastDecreaseSpeed,
                                  button: true,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _decrease(engine, l10n),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Semantics(
                                  label:
                                      s.isPlaying ? l10n.fastPause : l10n.fastPlay,
                                  button: true,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _toggle(engine, l10n),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Semantics(
                                  label: l10n.fastIncreaseSpeed,
                                  button: true,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _increase(engine, l10n),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _WordRow(
                              state: s,
                              palette: palette,
                              fontFamily: fontFamily,
                              scale: scale,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _WpmHints(
                              paused: !s.isPlaying,
                              step: s.settings.step,
                              speedLocked: s.settings.speedLockEnabled,
                              reduced: readerSettings?.reducedMotion ?? false,
                              l10n: l10n,
                              palette: palette,
                            ),
                          ),
                        ),
                        if (_feedback != null)
                          Positioned(
                            top: 24,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child:
                                  Center(child: _FeedbackChip(text: _feedback!)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _FastBottomBar(
                  l10n: l10n,
                  state: s,
                  palette: palette,
                  modeLocked: widget.modeLocked,
                  paused: !s.isPlaying,
                  reduced: readerSettings?.reducedMotion ?? false,
                  onToggleModeLock: widget.onToggleModeLock,
                  onPlayPause: () => _toggle(engine, l10n),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// RSVP words: two dimmed context words per side and the current word in the
/// centre. The current word's box is centred symmetrically (equal side cells)
/// and all words share the same floor (bottom-aligned), so the smaller side
/// words sit on the current word's baseline rather than its vertical middle.
class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.state,
    required this.palette,
    required this.fontFamily,
    required this.scale,
  });

  final FastModeState state;
  final ReaderPalette palette;
  final ReaderFontFamily fontFamily;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final side = fontFamily.applyTo(TextStyle(
      fontSize: 26 * scale,
      color: palette.dim,
      height: 1.0,
    ));
    final current = fontFamily.applyTo(TextStyle(
      fontSize: 58 * scale,
      fontWeight: FontWeight.w600,
      color: palette.text,
      height: 1.0,
    ));
    final showAdjacent = state.settings.showAdjacentContext;

    Widget word(String? text, TextStyle style) => Text(
          text ?? '',
          style: style,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        );

    return LayoutBuilder(builder: (context, constraints) {
      final gap = SizedBox(width: 16 * scale);
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end, // same floor
            children: <Widget>[
              // Left context, hugging toward the centre.
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (showAdjacent) ...<Widget>[
                      Flexible(child: word(state.tokenAt(-2)?.rawText, side)),
                      gap,
                      Flexible(child: word(state.tokenAt(-1)?.rawText, side)),
                      gap,
                    ],
                  ],
                ),
              ),
              // Current word: bounded so FittedBox can shrink long words, and
              // the inflexible middle child stays screen-centred.
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: constraints.maxWidth * 0.46),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: word(state.currentToken?.rawText, current),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (showAdjacent) ...<Widget>[
                      gap,
                      Flexible(child: word(state.tokenAt(1)?.rawText, side)),
                      gap,
                      Flexible(child: word(state.tokenAt(2)?.rawText, side)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Gray tap hints for the ±WPM zones, shown while paused and faded out on
/// resume. Sit a little below the top edge, no repeated +/- glyph, larger text.
class _WpmHints extends StatelessWidget {
  const _WpmHints({
    required this.paused,
    required this.step,
    required this.speedLocked,
    required this.reduced,
    required this.l10n,
    required this.palette,
  });

  final bool paused;
  final int step;
  final bool speedLocked;
  final bool reduced;
  final AppLocalizations l10n;
  final ReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    if (speedLocked) return const SizedBox.shrink();
    final duration =
        reduced ? Duration.zero : const Duration(milliseconds: 300);
    final style = TextStyle(
      color: palette.dim,
      fontSize: 19,
      fontWeight: FontWeight.w500,
    );
    Widget fade(Widget child) =>
        AnimatedOpacity(opacity: paused ? 1 : 0, duration: duration, child: child);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        children: <Widget>[
          Align(
            alignment: const Alignment(-1, -0.55),
            child: fade(Text('-$step ${l10n.wpm}', style: style)),
          ),
          Align(
            alignment: const Alignment(1, -0.55),
            child: fade(Text('+$step ${l10n.wpm}', style: style)),
          ),
        ],
      ),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(text, style: TextStyle(color: scheme.onInverseSurface)),
      ),
    );
  }
}

class _FastBottomBar extends StatelessWidget {
  const _FastBottomBar({
    required this.l10n,
    required this.state,
    required this.palette,
    required this.modeLocked,
    required this.paused,
    required this.reduced,
    required this.onToggleModeLock,
    required this.onPlayPause,
  });

  final AppLocalizations l10n;
  final FastModeState state;
  final ReaderPalette palette;
  final bool modeLocked;
  final bool paused;
  final bool reduced;
  final VoidCallback onToggleModeLock;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration =
        reduced ? Duration.zero : const Duration(milliseconds: 300);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: l10n.readerModeLock,
              color: palette.text,
              icon: Icon(modeLocked ? Icons.lock : Icons.lock_open_outlined),
              onPressed: onToggleModeLock,
            ),
            // "Lock rotation" label to the right of the lock, only while
            // paused (fades out when reading resumes).
            AnimatedOpacity(
              opacity: paused ? 1 : 0,
              duration: duration,
              child: Text(
                l10n.fastLockRotationHint,
                style: theme.textTheme.bodyMedium?.copyWith(color: palette.dim),
              ),
            ),
            Expanded(
              child: Semantics(
                label:
                    '${l10n.fastCurrentSpeedLabel}, ${l10n.readerProgressLabel}',
                value:
                    '${state.wpm} ${l10n.wpm}, ${state.progressPercent.round()}%',
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('${state.wpm} ${l10n.wpm}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: palette.text)),
                    Text('${state.progressPercent.round()}%',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: palette.dim)),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: state.isPlaying ? l10n.fastPause : l10n.fastPlay,
              color: palette.text,
              icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: onPlayPause,
            ),
          ],
        ),
      ),
    );
  }
}
