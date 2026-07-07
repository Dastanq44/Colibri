import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../application/reader_controller.dart';
import '../../domain/pdf_book_source.dart';

/// Normal-mode PDF reader (TASK-0704): renders pages with pdfrx, resumes at
/// the saved page, and persists progress by page number on every page change.
/// PDFs have no fast mode in MVP, so this view ignores orientation.
class PdfReaderView extends ConsumerStatefulWidget {
  const PdfReaderView({super.key, required this.source});

  final PdfBookSource source;

  @override
  ConsumerState<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends ConsumerState<PdfReaderView> {
  int? _pageNumber;
  int? _pageCount;

  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null) return;
    setState(() => _pageNumber = pageNumber);
    final pageCount = _pageCount;
    if (pageCount != null) {
      ref
          .read(readerControllerProvider(widget.source.bookId).notifier)
          .savePdfPage(pageNumber: pageNumber, pageCount: pageCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pageNumber = _pageNumber ?? widget.source.initialPageNumber;
    final pageCount = _pageCount;

    return Scaffold(
      appBar: AppBar(title: Text(widget.source.title)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PdfViewer.file(
              widget.source.filePath,
              initialPageNumber: widget.source.initialPageNumber,
              params: PdfViewerParams(
                onDocumentChanged: (document) {
                  if (!mounted) return;
                  setState(() => _pageCount = document?.pages.length);
                },
                onPageChanged: _onPageChanged,
                errorBannerBuilder: (context, error, stackTrace, documentRef) =>
                    Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.error_outline,
                            size: 56, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Text(l10n.readerOpenError,
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: LinearProgressIndicator(
                      value: pageCount == null || pageCount < 1
                          ? null
                          : (pageNumber / pageCount).clamp(0.0, 1.0),
                      semanticsLabel: l10n.readerProgressLabel,
                      semanticsValue:
                          pageCount == null ? '' : '$pageNumber / $pageCount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExcludeSemantics(
                    child: Text(
                      pageCount == null ? '$pageNumber' : '$pageNumber / $pageCount',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
