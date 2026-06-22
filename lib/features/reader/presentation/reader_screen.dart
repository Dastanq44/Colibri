import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../application/reader_controller.dart';
import '../domain/reader_progress.dart';

/// Portrait normal reader. TXT books render with tap-left/tap-right paging and
/// a bottom progress bar; unsupported formats show a friendly message.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(readerControllerProvider(widget.bookId).notifier).saveNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(readerControllerProvider(widget.bookId));
    final controller =
        ref.read(readerControllerProvider(widget.bookId).notifier);

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
          child: _Message(
            icon: Icons.error_outline,
            text: l10n.readerOpenError,
          ),
        ),
      ReaderReady() => _ReaderView(
          l10n: l10n,
          state: state,
          onPrevious: controller.previousPage,
          onNext: controller.nextPage,
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

class _ReaderView extends StatelessWidget {
  const _ReaderView({
    required this.l10n,
    required this.state,
    required this.onPrevious,
    required this.onNext,
  });

  final AppLocalizations l10n;
  final ReaderReady state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(state.document.title)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Text(
                      state.currentPage.text.trim(),
                      style: const TextStyle(
                        fontSize: AppConstants.readerFontSizeDefault,
                        height: AppConstants.readerLineHeightDefault,
                      ),
                    ),
                  ),
                ),
                // Transparent tap zones over the text: left = previous, right =
                // next. Translucent so vertical drags still scroll the text.
                Positioned.fill(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          label: l10n.readerPreviousPage,
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: onPrevious,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          label: l10n.readerNextPage,
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: onNext,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _BottomBar(l10n: l10n, progress: state.progress),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.l10n, required this.progress});

  final AppLocalizations l10n;
  final ReaderProgress progress;

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
              icon: const Icon(Icons.lock_open_outlined),
              onPressed: () => _comingSoon(context),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LinearProgressIndicator(
                    value: (progress.percent / 100).clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.percent.round()}%',
                    style: theme.textTheme.bodySmall,
                  ),
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
