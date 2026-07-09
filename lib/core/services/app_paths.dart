import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Container-safe path resolution.
///
/// iOS moves the app sandbox container (new UUID) on app updates/reinstalls,
/// so an **absolute** path persisted in the database points at a dead
/// location after the next install — books, covers and the avatar silently
/// "disappear" even though the files were migrated to the new container.
///
/// [absolute] re-bases any stored path onto the *current* Documents directory
/// at read time: absolute paths from an older container are recognised by
/// their `/Documents/` segment and re-rooted; relative paths are joined; and
/// non-Documents absolute paths (tests, tmp) pass through untouched.
abstract final class AppPaths {
  const AppPaths._();

  static const String _marker = '/Documents/';

  static String? _documents;

  /// Must run once before the app touches any stored path (see `main()`).
  static Future<void> ensureInitialized() async {
    _documents ??= (await getApplicationDocumentsDirectory()).path;
  }

  /// Test seam.
  static set documentsOverride(String path) => _documents = path;

  static String get documents {
    final docs = _documents;
    assert(docs != null, 'AppPaths.ensureInitialized() was not awaited');
    return docs!;
  }

  /// Resolves a stored file path to a usable absolute path for the current
  /// container. Returns null for null/empty input.
  static String? absolute(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    final i = stored.indexOf(_marker);
    if (i >= 0) {
      // Absolute path from this or an older container: re-base the part
      // after /Documents/ onto the current Documents directory. Identical
      // for the current container; heals paths from previous ones.
      return p.join(documents, stored.substring(i + _marker.length));
    }
    if (p.isAbsolute(stored)) return stored;
    return p.join(documents, stored);
  }
}
