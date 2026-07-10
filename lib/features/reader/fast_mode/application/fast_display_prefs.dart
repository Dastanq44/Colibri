import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/local/database_providers.dart';

/// Uniform-words display mode: no centre-word magnification/highlight and no
/// side-word dimming — every word renders at the same size and colour.
/// Persisted in the key-value table (device-local display preference).
final fastUniformWordsProvider =
    AsyncNotifierProvider<FastUniformWordsController, bool>(
  FastUniformWordsController.new,
);

class FastUniformWordsController extends AsyncNotifier<bool> {
  static const String _key = 'fast_uniform_words';

  @override
  Future<bool> build() async =>
      await ref.read(appDatabaseProvider).keyValueDao.getValue(_key) == '1';

  Future<void> toggle() async {
    final next = !(state.valueOrNull ?? false);
    state = AsyncData(next);
    await ref
        .read(appDatabaseProvider)
        .keyValueDao
        .setValue(_key, next ? '1' : '0');
  }
}

/// Whether the one-time fast-mode guide has been shown. Persisted so the
/// step-by-step overlay appears only on the very first fast-mode open.
final fastGuideSeenProvider =
    AsyncNotifierProvider<FastGuideSeenController, bool>(
  FastGuideSeenController.new,
);

class FastGuideSeenController extends AsyncNotifier<bool> {
  static const String _key = 'fast_guide_seen';

  @override
  Future<bool> build() async =>
      await ref.read(appDatabaseProvider).keyValueDao.getValue(_key) == '1';

  Future<void> markSeen() async {
    state = const AsyncData(true);
    await ref.read(appDatabaseProvider).keyValueDao.setValue(_key, '1');
  }
}
