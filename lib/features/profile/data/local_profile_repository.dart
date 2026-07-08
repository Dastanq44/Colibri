import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/local/app_database.dart';

/// Device-local profile extras that have no cloud column yet: the avatar
/// image and the bio/description. Stored in the key-value table (no schema
/// migration); the avatar file itself is copied into the app documents dir so
/// it survives the picker's temp-file cleanup.
class LocalProfileRepository {
  LocalProfileRepository(this._db, {Directory? baseDirectory})
      : _baseOverride = baseDirectory;

  static const String _avatarKey = 'profile_avatar_path';
  static const String _bioKey = 'profile_bio';

  final AppDatabase _db;
  final Directory? _baseOverride;

  Future<String?> getAvatarPath() async {
    final path = await _db.keyValueDao.getValue(_avatarKey);
    if (path == null || path.isEmpty) return null;
    return await File(path).exists() ? path : null;
  }

  /// Copies [sourcePath] (a picker temp file) into app storage and persists
  /// it as the avatar. Returns the stored path.
  Future<String> setAvatarFromFile(String sourcePath) async {
    final base = _baseOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'profile'));
    await dir.create(recursive: true);
    // Timestamped name so Image caches never show a stale avatar.
    final dest = p.join(
      dir.path,
      'avatar_${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}',
    );
    await File(sourcePath).copy(dest);
    // Best-effort cleanup of the previous avatar file.
    final old = await _db.keyValueDao.getValue(_avatarKey);
    await _db.keyValueDao.setValue(_avatarKey, dest);
    if (old != null && old.isNotEmpty && old != dest) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    return dest;
  }

  Future<String> getBio() async =>
      await _db.keyValueDao.getValue(_bioKey) ?? '';

  Future<void> setBio(String bio) =>
      _db.keyValueDao.setValue(_bioKey, bio.trim());
}
