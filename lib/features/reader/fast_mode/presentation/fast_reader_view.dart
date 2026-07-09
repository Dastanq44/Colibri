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

  // Hold-and-drag scrubbing through the words.
  bool _scrubbing = false;
  int _scrubSteps = 0;

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
      unawaited(ref.read(analyticsRepositoryProvider).logEvent('wpm_changed',
          params: {'wpm': engine.state.wpm, 'delta': -1}));
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
      unawaited(ref.read(analyticsRepositoryProvider).logEvent('wpm_changed',
          params: {'wpm': engine.state.wpm, 'delta': 1}));
      _flash('+${engine.state.settings.step} ${l10n.wpm}');
    }
  }

  void _toggle(FastModeEngine engine, AppLocalizations l10n) {
    engine.togglePlayPause();
    unawaited(ref.read(analyticsRepositoryProvider).logEvent(
        'pause_play_toggled',
        params: {'playing': engine.state.isPlaying}));
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
                    // Hold-and-drag: scrub backward/forward through the words
                    // (right = back). Pauses playback; hints hide and the
                    // words span the whole screen while scrubbing.
                    onLongPressStart: (_) {
                      engine.pause();
                      _haptic(HapticFeedback.mediumImpact);
                      setState(() {
                        _scrubbing = true;
                        _scrubSteps = 0;
                      });
                    },
                    onLongPressMoveUpdate: (d) {
                      const stepWidth = 44.0;
                      final steps = (d.offsetFromOrigin.dx / stepWidth).round();
                      if (steps == _scrubSteps) return;
                      final delta = steps - _scrubSteps;
                      _scrubSteps = steps;
                      // Dragging right reveals earlier words (go back).
                      engine.seekToTokenIndex(
                          engine.state.currentTokenIndex - delta);
                      _haptic(HapticFeedback.selectionClick);
                    },
                    onLongPressEnd: (_) => setState(() => _scrubbing = false),
                    onLongPressCancel: () => setState(() => _scrubbing = false),
                    onScaleStart: (_) => _pinchBase =
                        ref.read(fastWordScaleProvider).valueOrNull,
                    onScaleUpdate: (d) {
                      // Accept multi-touch pinch (pointerCount >= 2) and
                      // trackpad pinch (reported as pointerCount 0); ignore a
                      // single-finger drag (1) so it falls through to the taps.
                      if (d.pointerCount == 1) return;
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
                                  label: s.isPlaying
                                      ? l10n.fastPause
                                      : l10n.fastPlay,
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
                              scrubbing: _scrubbing,
                              reduced:
                                  readerSettings?.reducedMotion ?? false,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _WpmHints(
                              paused: !s.isPlaying && !_scrubbing,
                              step: s.settings.step,
                              speedLocked: s.settings.speedLockEnabled,
                              reduced: readerSettings?.reducedMotion ?? false,
                              l10n: l10n,
                              palette: palette,
                            ),
                          ),
                        ),
                        // Feedback sits between the words and the WPM bar so
                        // it is in the natural line of sight.
                        if (_feedback != null && !_scrubbing)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 18,
                            child: IgnorePointer(
                              child: Center(
                                child: _FeedbackChip(
                                    text: _feedback!, palette: palette),
                              ),
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
                  paused: !s.isPlaying && !_scrubbing,
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

/// RSVP words: the current word centred, flanked by as many dimmed context
/// words per side as fit inside an invisible border, all sharing the same floor
/// (bottom-aligned).
///
/// Context words are laid out outward from the current word and measured, not
/// capped at a fixed count. A word shows when at least half of it sits inside
/// the border (midpoint rule); the first word that falls past it ends that
/// side, so the closest words never get clipped. While **playing** the border
/// is an inset band that keeps the eye near the centre; while **paused** the
/// border is the screen edge, so context spans the whole width and a word that
/// crosses the edge is still shown (clipped to the visible part). Because the
/// fit is measured, larger pinch-zoom sizes simply show fewer words.
class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.state,
    required this.palette,
    required this.fontFamily,
    required this.scale,
    required this.scrubbing,
    required this.reduced,
  });

  final FastModeState state;
  final ReaderPalette palette;
  final ReaderFontFamily fontFamily;
  final double scale;

  /// Honours the reduced-motion setting (disables the grow-in animation).
  final bool reduced;

  /// Hold-and-drag scrubbing: no border at all — words span the full screen
  /// and an edge-crossing word stays visible (clipped), never hidden.
  final bool scrubbing;

  /// Fraction of the half-width the playing-mode border sits at. Kept tight
  /// (0.6) so only a word or two shows per side while playing — less visual
  /// noise around the highlighted word aids concentration. Paused mode still
  /// spans the whole screen.
  static const double _playingBandFactor = 0.6;
  static const int _maxWordsPerSide = 32;

  /// Edge punctuation (quotes, commas, dots, brackets...) is kept visible but
  /// ignored when centring the current word, so the *letters* sit centred.
  static final RegExp _edges =
      RegExp(r'^([^\p{L}\p{N}]*)(.*?)([^\p{L}\p{N}]*)$', unicode: true);

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final currentStyle = fontFamily.applyTo(TextStyle(
      fontSize: 58 * scale,
      fontWeight: FontWeight.w600,
      color: palette.text,
      height: 1.0,
    ));
    final showAdjacent = state.settings.showAdjacentContext;
    final playing = state.isPlaying;

    Size measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      return painter.size;
    }

    // Scrub emphasis eases in/out: side words grow and gain contrast while
    // the reader drags through the text.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: scrubbing ? 1 : 0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, scrubT, _) {
        final sideStyle = fontFamily.applyTo(TextStyle(
          fontSize: (26 + 6 * scrubT) * scale,
          color: Color.lerp(palette.dim, palette.text, 0.55 * scrubT),
          height: 1.0,
        ));
        return LayoutBuilder(builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          final centreX = maxW / 2;
          final gap = 16 * scale;

          // Current word: shrink to its 0.46-width box if it would overflow.
          final currentText = state.currentToken?.rawText ?? '';
          final rawCurrent = currentText.isEmpty
              ? Size.zero
              : measure(currentText, currentStyle);
          final centreMaxW = maxW * 0.46;
          final fit = (rawCurrent.width > centreMaxW && rawCurrent.width > 0)
              ? centreMaxW / rawCurrent.width
              : 1.0;
          final centreW = rawCurrent.width * fit;
          final centreH = rawCurrent.height * fit;

          // Centre on the word's *letters*: leading/trailing punctuation (quotes,
          // commas, dots) stays rendered but does not shift the anchor.
          var anchorHalf = centreW / 2;
          if (currentText.isNotEmpty) {
            final m = _edges.firstMatch(currentText);
            final prefix = m?.group(1) ?? '';
            final core = m?.group(2) ?? '';
            if (core.isNotEmpty &&
                (prefix.isNotEmpty || (m?.group(3) ?? '').isNotEmpty)) {
              final prefixW =
                  prefix.isEmpty ? 0.0 : measure(prefix, currentStyle).width;
              final coreW =
                  measure(prefix + core, currentStyle).width - prefixW;
              anchorHalf = fit * (prefixW + coreW / 2);
            }
          }
          final leftHalf = anchorHalf; // word extent left of the screen centre
          final rightHalf = centreW - anchorHalf; // ...and right of it

          // The border, measured from the centre: an inset band while playing
          // (midpoint rule). Paused and scrubbing have NO hide-barrier — words
          // are placed until fully offscreen and the ClipRect cuts the crossing
          // word at the screen edge.
          final bandHalf = (maxW / 2) * _playingBandFactor;
          final unbounded = scrubbing || !playing;

          // Floor-align every word (shared bottom) with the row vertically centred.
          final sideH = measure('Ag', sideStyle).height;
          final rowH = centreH > sideH ? centreH : sideH;
          final bottom = (maxH - rowH) / 2;

          final children = <Widget>[];
          if (currentText.isNotEmpty) {
            children.add(Positioned(
              left: centreX - leftHalf,
              bottom: bottom,
              width: centreW,
              height: centreH,
              // Grow-in: the word starts at the side-word scale and eases up
              // to full size, so the incoming word visibly "becomes" the
              // highlighted one instead of snapping. Keyed per token so the
              // animation restarts on every advance.
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(state.currentTokenIndex),
                tween: Tween<double>(begin: reduced ? 1.0 : 26 / 58, end: 1),
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                builder: (context, grow, child) => Transform.scale(
                  scale: grow,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(currentText,
                      style: currentStyle, maxLines: 1, softWrap: false),
                ),
              ),
            ));
          }

          if (showAdjacent && currentText.isNotEmpty) {
            for (final dir in const <int>[-1, 1]) {
              // Distance from the centre to this word's near (inner) edge, which
              // starts at the current word's actual edge on this side.
              var inner = (dir < 0 ? leftHalf : rightHalf) + gap;
              for (var step = 1; step <= _maxWordsPerSide; step++) {
                final text = state.tokenAt(dir * step)?.rawText;
                if (text == null || text.isEmpty) break;
                final w = measure(text, sideStyle).width;
                if (w <= 0) break;
                if (unbounded) {
                  // No hide-barrier: stop only once fully offscreen; a word
                  // crossing the screen edge still shows its visible part (cut).
                  if (inner >= maxW / 2) break;
                } else if (step > 1) {
                  // Show when the word's midpoint is inside the border; the
                  // first one that isn't ends this side (outer words are
                  // further still). The nearest word (step 1) is exempt —
                  // there is always at least one word on each side.
                  if (inner + w / 2 > bandHalf) break;
                }
                children.add(Positioned(
                  left: dir < 0 ? centreX - inner - w : centreX + inner,
                  bottom: bottom,
                  child: Text(text,
                      style: sideStyle, maxLines: 1, softWrap: false),
                ));
                inner += w + gap;
              }
            }
          }

          // Clip so words that cross the screen edge show only their
          // on-screen part.
          return ClipRect(child: Stack(children: children));
        });
      },
    );
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
    Widget fade(Widget child) => AnimatedOpacity(
        opacity: paused ? 1 : 0, duration: duration, child: child);

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
  const _FeedbackChip({required this.text, required this.palette});

  final String text;
  final ReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    // Plain text, identical in size/colour to the ±WPM hints — no chip
    // background.
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: TextStyle(
          color: palette.dim,
          fontSize: 19,
          fontWeight: FontWeight.w500,
        ),
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
        // Stack (not Row) so the speed/progress stays at the true screen
        // centre regardless of the differently-sized clusters on each side —
        // the "Lock rotation" label no longer shoves it off-centre.
        child: SizedBox(
          height: 56,
          child: Stack(
            children: <Widget>[
              // Centred speed + progress.
              Center(
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
              // Left cluster: mode lock + the paused-only "Lock rotation" hint.
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: l10n.readerModeLock,
                      color: palette.text,
                      icon: Icon(
                          modeLocked ? Icons.lock : Icons.lock_open_outlined),
                      onPressed: onToggleModeLock,
                    ),
                    AnimatedOpacity(
                      opacity: paused ? 1 : 0,
                      duration: duration,
                      child: Text(
                        l10n.readerModeLock,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: palette.dim),
                      ),
                    ),
                  ],
                ),
              ),
              // Right: play/pause.
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: state.isPlaying ? l10n.fastPause : l10n.fastPlay,
                  color: palette.text,
                  icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: onPlayPause,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
