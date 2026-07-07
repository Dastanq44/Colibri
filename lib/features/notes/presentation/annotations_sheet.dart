import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/result/result.dart';
import '../application/notes_providers.dart';

/// Bottom sheet listing a book's bookmarks and notes (TASK-1103). Tapping an
/// entry jumps the reader to its saved location; the trailing icon deletes
/// (soft delete, synced later).
class AnnotationsSheet extends ConsumerWidget {
  const AnnotationsSheet({
    super.key,
    required this.bookId,
    required this.onJump,
  });

  final String bookId;

  /// Called with the annotation's character offset; the caller closes the
  /// sheet and moves the reader.
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookmarksAsync = ref.watch(bookBookmarksProvider(bookId));
    final notesAsync = ref.watch(bookNotesProvider(bookId));
    final repo = ref.read(notesRepositoryProvider);

    // Don't conflate "still loading" with "no annotations": the empty state
    // must only appear once both streams have actually emitted.
    if (!bookmarksAsync.hasValue || !notesAsync.hasValue) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final bookmarks = bookmarksAsync.requireValue;
    final notes = notesAsync.requireValue;

    if (bookmarks.isEmpty && notes.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.bookmark_outline,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(l10n.annotationsEmpty, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          if (bookmarks.isNotEmpty) _SectionHeader(l10n.annotationsBookmarks),
          for (final bookmark in bookmarks)
            _AnnotationTile(
              icon: Icons.bookmark_outline,
              title: bookmark.label ?? l10n.annotationBookmarkUntitled,
              subtitle: _formatDate(context, bookmark.createdAt),
              offset: bookmark.textOffset,
              onJump: onJump,
              onDelete: () => _delete(context, repo.deleteBookmark(bookmark.id)),
              deleteTooltip: l10n.annotationDelete,
            ),
          if (notes.isNotEmpty) _SectionHeader(l10n.annotationsNotes),
          for (final note in notes)
            _AnnotationTile(
              icon: Icons.sticky_note_2_outlined,
              title: note.noteText,
              subtitle: _formatDate(context, note.createdAt),
              offset: note.textOffset,
              onJump: onJump,
              onDelete: () => _delete(context, repo.deleteNote(note.id)),
              deleteTooltip: l10n.annotationDelete,
            ),
        ],
      ),
    );
  }

  /// Surfaces delete failures — a silently ignored tap reads as a broken app.
  Future<void> _delete(
    BuildContext context,
    Future<Result<void>> operation,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await operation;
    if (result is Err) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.annotationDeleteFailed)),
      );
    }
  }

  String _formatDate(BuildContext context, DateTime? date) => date == null
      ? ''
      : MaterialLocalizations.of(context).formatShortDate(date.toLocal());
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _AnnotationTile extends StatelessWidget {
  const _AnnotationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.offset,
    required this.onJump,
    required this.onDelete,
    required this.deleteTooltip,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int? offset;
  final ValueChanged<int> onJump;
  final VoidCallback onDelete;
  final String deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final target = offset;
    return ListTile(
      leading: Icon(icon),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: target == null ? null : () => onJump(target),
      trailing: IconButton(
        tooltip: deleteTooltip,
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}
