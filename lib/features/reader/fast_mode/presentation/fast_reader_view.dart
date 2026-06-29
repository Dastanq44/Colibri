import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../../../app/theme/reader_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../settings/application/reader_settings_providers.dart';
import '../application/fast_mode_engine.dart';
import '../application/fast_mode_providers.dart';
import '../domain/fast_mode_playback_state.dart';
import '../domain/fast_mode_state.dart';

/// Landscape fast (RSVP) reader. Centered current word, optional dimmed
/// neighbours, tap-left/center/right to slow/pause/speed up, with transient
/// feedback. Honors persisted fast settings (WPM bounds, speed lock, adjacent
/// context) and the reader theme palette.
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

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
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
      _flash('-${engine.state.settings.step} ${l10n.wpm}');
    }
  }

  void _increase(FastModeEngine engine, AppLocalizations l10n) {
    if (engine.state.settings.speedLockEnabled) {
      _flash(l10n.fastSpeedLocked);
      return;
    }
    if (engine.increaseWpm()) {
      _flash('+${engine.state.settings.step} ${l10n.wpm}');
    }
  }

  void _toggle(FastModeEngine engine, AppLocalizations l10n) {
    engine.togglePlayPause();
    if (!engine.state.isPlaying) _flash(l10n.fastPaused);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = ref.watch(fastModeEngineProvider(widget.bookId));
    final theme = ref.watch(readerSettingsProvider).valueOrNull?.theme ??
        ReaderThemeVariant.light;
    final palette = ReaderPalette.of(theme);

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
                                label: s.isPlaying ? l10n.fastPause : l10n.fastPlay,
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
                          child: _TokenColumn(state: s, palette: palette),
                        ),
                      ),
                      if (_feedback != null)
                        Positioned(
                          top: 24,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(child: _FeedbackChip(text: _feedback!)),
                          ),
                        ),
                    ],
                  ),
                ),
                _FastBottomBar(
                  l10n: l10n,
                  state: s,
                  palette: palette,
                  modeLocked: widget.modeLocked,
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

class _TokenColumn extends StatelessWidget {
  const _TokenColumn({required this.state, required this.palette});

  final FastModeState state;
  final ReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.textTheme.titleMedium?.copyWith(color: palette.dim);
    final showAdjacent = state.settings.showAdjacentContext;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showAdjacent)
            Text(state.previousToken?.rawText ?? '', style: dim),
          const SizedBox(height: 12),
          Text(
            state.currentToken?.rawText ?? '',
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall
                ?.copyWith(fontWeight: FontWeight.w600, color: palette.text),
          ),
          const SizedBox(height: 12),
          if (showAdjacent) Text(state.nextToken?.rawText ?? '', style: dim),
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
      child: Text(text, style: TextStyle(color: scheme.onInverseSurface)),
    );
  }
}

class _FastBottomBar extends StatelessWidget {
  const _FastBottomBar({
    required this.l10n,
    required this.state,
    required this.palette,
    required this.modeLocked,
    required this.onToggleModeLock,
    required this.onPlayPause,
  });

  final AppLocalizations l10n;
  final FastModeState state;
  final ReaderPalette palette;
  final bool modeLocked;
  final VoidCallback onToggleModeLock;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Expanded(
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
