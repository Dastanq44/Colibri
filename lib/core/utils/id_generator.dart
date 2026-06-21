import 'dart:math';

/// Generates random, collision-resistant ids for locally-created entities
/// (device id, reading sessions, notes, bookmarks, sync-queue items, ...).
///
/// Uses a cryptographically-secure RNG and returns 32 lowercase hex chars
/// (128 bits). Avoids pulling in a uuid dependency for the foundation.
abstract final class IdGenerator {
  const IdGenerator._();

  static final Random _rng = Random.secure();

  static String newId() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
