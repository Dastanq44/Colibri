import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../application/reader_controller.dart';
import '../domain/reader_mode.dart';
import '../domain/reader_progress.dart';
import '../fast_mode/application/fast_mode_providers.dart';
import '../fast_mode/presentation/fast_reader_view.dart';

/// The reader. Portrait = normal paged TXT reader; landscape = fast mode (TXT
/// only). Orientation only switches the mode *inside this screen* — the app is
/// never globally orientation-locked. Mode lock freezes the current mode.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  ReaderMode _effectiveMode = ReaderMode.normal;
  ReaderMode? _pendingMode;
  Timer? _switchTimer;
  // TODO(reader-settings): persist mode lock to local_reader_settings.
  bool _modeLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(readerControllerProvider(widget.bookId).notifier).saveNow();
      ref.read(fastModeEngineProvider(widget.bookId)).savePosition();
    }
  }

  /// Debounced orientation → mode switch (stability threshold avoids flips).
  void _scheduleModeSwitch(Orientation orientation) {
    if (_modeLocked) return;
    final desired = orientation == Orientation.landscape
        ? ReaderMode.fast
        : ReaderMode.normal;
    if (desired == _effectiveMode) {
      _switchTimer?.cancel();
      _pendingMode = null;
      return;
    }
    if (_pendingMode == desired) return;
    _pendingMode = desired;
    _switchTimer?.cancel();
    _switchTimer = Timer(AppConstants.modeSwitchStabilityThreshold, () {
      if (!mounted) return;
      _commitModeSwitch(desired);
    });
  }

  void _commitModeSwitch(ReaderMode to) {
    _handoffPosition(to);
    setState(() {
      _effectiveMode = to;
      _pendingMode = null;
    });
  }

  /// Carries the current text position across the mode boundary so reading
  /// continues from the same place.
  void _handoffPosition(ReaderMode to) {
    final reader = ref.read(readerControllerProvider(widget.bookId).notifier);
    final engine = ref.read(fastModeEngineProvider(widget.bookId));
    if (to == ReaderMode.fast) {
      final offset = reader.currentStartOffset;
      if (offset != null) engine.seekToOffset(offset);
      engine.pause(); // fast mode starts paused
    } else {
      engine.pause();
      final offset = engine.currentStartOffset;
      if (offset != null) reader.jumpToOffset(offset);
    }
  }

  void _toggleModeLock() {
    setState(() {
      _modeLocked = !_modeLocked;
      if (_modeLocked) {
        _switchTimer?.cancel();
        _pendingMode = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(readerControllerProvider(widget.bookId));

    // Fast mode only applies to a successfully loaded (TXT) book.
    if (state is ReaderReady) {
      _scheduleModeSwitch(MediaQuery.orientationOf(context));
    }

    return switch (state) {
      ReaderLoading() => _Scaffold(
          title: l10n.readerTitle,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ReaderEmpty() => _Scaffold(
          title: l10n.readerTitle,
          child: _Message(icon: Icons.menu_book_outlined, text: l10n.readerEmpty),
        ),
      ReaderUnsupported(:final reason) => _Scaffold(
          title: l10n.readerUnsupportedTitle,
          child: _Message(
            icon: Icons.block_outlined,
            text: _unsupportedText(l10n, reason),
          ),
        ),
      ReaderFailed() => _Scaffold(
          title: l10n.readerTitle,
          child: _Message(icon: Icons.error_outline, text: l10n.readerOpenError),
        ),
      ReaderReady() => _effectiveMode == ReaderMode.fast
          ? FastReaderView(
              bookId: widget.bookId,
              modeLocked: _modeLocked,
              onToggleModeLock: _toggleModeLock,
            )
          : _NormalReaderView(
              l10n: l10n,
              state: state,
              modeLocked: _modeLocked,
              onToggleModeLock: _toggleModeLock,
              onPrevious: ref
                  .read(readerControllerProvider(widget.bookId).notifier)
                  .previousPage,
              onNext: ref
                  .read(readerControllerProvider(widget.bookId).notifier)
                  .nextPage,
            ),
    };
  }

  String _unsupportedText(AppLocalizations l10n, ReaderUnsupportedReason reason) =>
      switch (reason) {
        ReaderUnsupportedReason.epub => l10n.readerEpubComingSoon,
        ReaderUnsupportedReason.pdf => l10n.readerPdfComingSoon,
        ReaderUnsupportedReason.generic => l10n.readerUnsupportedTitle,
      };
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: child);
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _NormalReaderView extends StatelessWidget {
  const _NormalReaderView({
    required this.l10n,
    required this.state,
    required this.modeLocked,
    required this.onToggleModeLock,
    required this.onPrevious,
    required this.onNext,
  });

  final AppLocalizations l10n;
  final ReaderReady state;
  final bool modeLocked;
  final VoidCallback onToggleModeLock;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(state.document.title)),
      body: Column(
        children: <Widget>[
          Expanded(
            // One gesture detector handles paging by tap half; vertical drags
            // still scroll the text below.
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Semantics(
                  customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
                    CustomSemanticsAction(label: l10n.readerPreviousPage):
                        onPrevious,
                    CustomSemanticsAction(label: l10n.readerNextPage): onNext,
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      if (details.localPosition.dx < constraints.maxWidth / 2) {
                        onPrevious();
                      } else {
                        onNext();
                      }
                    },
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Text(
                        state.currentPage.text.trim(),
                        style: const TextStyle(
                          fontSize: AppConstants.readerFontSizeDefault,
                          height: AppConstants.readerLineHeightDefault,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _NormalBottomBar(
            l10n: l10n,
            progress: state.progress,
            modeLocked: modeLocked,
            onToggleModeLock: onToggleModeLock,
          ),
        ],
      ),
    );
  }
}

class _NormalBottomBar extends StatelessWidget {
  const _NormalBottomBar({
    required this.l10n,
    required this.progress,
    required this.modeLocked,
    required this.onToggleModeLock,
  });

  final AppLocalizations l10n;
  final ReaderProgress progress;
  final bool modeLocked;
  final VoidCallback onToggleModeLock;

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.comingSoon)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: l10n.readerModeLock,
              icon: Icon(modeLocked ? Icons.lock : Icons.lock_open_outlined),
              onPressed: onToggleModeLock,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LinearProgressIndicator(
                    value: (progress.percent / 100).clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 4),
                  Text('${progress.percent.round()}%',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.readerMenu,
              icon: const Icon(Icons.more_vert),
              onPressed: () => _comingSoon(context),
            ),
          ],
        ),
      ),
    );
  }
}
