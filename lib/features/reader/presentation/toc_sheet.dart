import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../domain/toc_entry.dart';

/// Simple table-of-contents bottom sheet. Tapping an entry closes the sheet and
/// invokes [onSelect] (which jumps the reader to that chapter).
class TocSheet extends StatelessWidget {
  const TocSheet({super.key, required this.toc, required this.onSelect});

  final List<TocEntry> toc;
  final void Function(TocEntry entry) onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.tableOfContents,
                style: Theme.of(context).textTheme.titleLarge),
          ),
          if (toc.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Text(l10n.tocEmpty),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: toc.length,
                itemBuilder: (context, i) {
                  final entry = toc[i];
                  return ListTile(
                    leading: const Icon(CupertinoIcons.bookmark),
                    title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(entry);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
