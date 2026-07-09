import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../library/application/library_providers.dart';
import '../../library/domain/library_book.dart';
import '../application/profile_providers.dart';

/// Profile editor: avatar (camera / photo library), name, description, and
/// the favourite-books shelf with a "+" slot that opens a multi-select picker
/// over My Books.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.profileTakePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profileChooseFromLibrary),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
      if (picked == null || !mounted) return;
      await ref
          .read(localProfileRepositoryProvider)
          .setAvatarFromFile(picked.path);
      ref.invalidate(avatarPathProvider);
    } catch (_) {
      // Permission denied / cancelled — nothing to do.
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(localProfileRepositoryProvider).setBio(_bio.text);
      if (!mounted) return;
      ref.invalidate(profileBioProvider);
      final name = _name.text.trim();
      if (name.isNotEmpty) {
        final result =
            await ref.read(profileRepositoryProvider).updateDisplayName(name);
        // The screen may have been disposed while the update was in flight;
        // `ref` must not be touched after that.
        if (!mounted) return;
        result.when(
          ok: (_) => ref.invalidate(currentProfileProvider),
          err: (failure) =>
              messenger.showSnackBar(SnackBar(content: Text(failure.message))),
        );
      }
      navigator.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openFavoritesPicker() async {
    final books = ref.read(myBooksProvider).valueOrNull ?? const <LibraryBook>[];
    if (books.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FavoritesPickerSheet(books: books),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final avatarPath = ref.watch(avatarPathProvider).valueOrNull;
    final favorites = ref.watch(favoriteBooksProvider);

    // Seed the text fields once from current values.
    if (!_seeded) {
      final profile = ref.watch(currentProfileProvider).valueOrNull;
      final bio = ref.watch(profileBioProvider).valueOrNull;
      if (bio != null) {
        _name.text = profile?.displayName ?? '';
        _bio.text = bio;
        _seeded = true;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileEditProfile),
        actions: <Widget>[
          _saving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(onPressed: _save, child: Text(l10n.profileDone)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          // Avatar + change-photo link.
          Center(
            child: Column(
              children: <Widget>[
                GestureDetector(
                  onTap: _pickAvatar,
                  child: _Avatar(path: avatarPath, radius: 44),
                ),
                TextButton(
                  onPressed: _pickAvatar,
                  child: Text(l10n.profileChangePhoto),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.profileUsername,
              hintText: l10n.profileDisplayNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bio,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: l10n.profileBio,
              hintText: l10n.profileBioHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.profileFavorites, style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final book in favorites)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: BookCover(
                        coverPath: book.coverPath, width: 88, height: 132),
                  ),
                // "+" slot opens the multi-select picker.
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openFavoritesPicker,
                  child: Container(
                    width: 88,
                    height: 132,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add,
                        size: 28, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.path, required this.radius});

  final String? path;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (path != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(path!)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Icon(Icons.person, size: radius, color: scheme.onSurfaceVariant),
    );
  }
}

/// Multi-select over all My Books: tap toggles, checkmarks show selection,
/// Done applies the favourite flags in one pass.
class _FavoritesPickerSheet extends ConsumerStatefulWidget {
  const _FavoritesPickerSheet({required this.books});

  final List<LibraryBook> books;

  @override
  ConsumerState<_FavoritesPickerSheet> createState() =>
      _FavoritesPickerSheetState();
}

class _FavoritesPickerSheetState extends ConsumerState<_FavoritesPickerSheet> {
  late final Set<String> _selected = <String>{
    for (final b in widget.books)
      if (b.isFavorite) b.id,
  };

  Future<void> _apply() async {
    final repo = ref.read(libraryRepositoryProvider);
    for (final book in widget.books) {
      final want = _selected.contains(book.id);
      if (want != book.isFavorite) {
        await repo.setFavorite(book.id, want);
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(l10n.profileSelectFavorites,
                      style: theme.textTheme.titleMedium),
                ),
                TextButton(onPressed: _apply, child: Text(l10n.profileDone)),
              ],
            ),
          ),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 88 / 148,
              ),
              itemCount: widget.books.length,
              itemBuilder: (context, i) {
                final book = widget.books[i];
                final selected = _selected.contains(book.id);
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() {
                    selected ? _selected.remove(book.id) : _selected.add(book.id);
                  }),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            BookCover(coverPath: book.coverPath),
                            if (selected)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 22,
                                color: selected
                                    ? theme.colorScheme.primary
                                    : Colors.white,
                                shadows: const <Shadow>[
                                  Shadow(blurRadius: 4, color: Colors.black38),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
