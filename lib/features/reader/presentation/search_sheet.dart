import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../domain/book_text_search.dart';

/// Bottom sheet for in-book text search (reader menu spec 8.2). Searches the
/// same full text the paginator uses; tapping a result jumps the reader to
/// that offset.
class SearchSheet extends StatefulWidget {
  const SearchSheet({
    super.key,
    required this.fullText,
    required this.onJump,
  });

  final String fullText;
  final ValueChanged<int> onJump;

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  BookSearchResult _result = BookSearchResult.empty;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _searched = query.trim().isNotEmpty;
        _result = searchBookText(widget.fullText, query);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Keep the field above the keyboard inside the sheet.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              // iOS-native rounded search field with inline magnifier/clear.
              child: CupertinoSearchTextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                placeholder: l10n.searchInBookHint,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Flexible(
              child: _result.matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _searched ? l10n.searchNoResults : l10n.searchInBookHint,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      // Extra row flags a capped list — otherwise it reads
                      // as "the word stops appearing here".
                      itemCount:
                          _result.matches.length + (_result.truncated ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _result.matches.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              l10n.searchTruncated(_result.matches.length),
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        final match = _result.matches[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            match.snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text('${match.percent.round()}%'),
                          onTap: () => widget.onJump(match.offset),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
