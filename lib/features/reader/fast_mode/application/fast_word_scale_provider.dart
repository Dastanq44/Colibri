import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/local/database_providers.dart';

/// Persisted zoom factor for the fast-mode word sizes (pinch to change),
/// stored in the key/value table so no schema migration is needed.
final fastWordScaleProvider =
    AsyncNotifierProvider<FastWordScaleController, double>(
  FastWordScaleController.new,
);

class FastWordScaleController extends AsyncNotifier<double> {
  static const String _key = 'fast_word_scale';
  static const double min = 0.6;
  static const double max = 2.4;
  static const double defaultScale = 1.0;

  @override
  Future<double> build() async {
    final raw =
        await ref.read(appDatabaseProvider).keyValueDao.getValue(_key);
    return (double.tryParse(raw ?? '') ?? defaultScale).clamp(min, max);
  }

  /// Updates the live scale (during a pinch); does not persist.
  void preview(double scale) {
    state = AsyncData(scale.clamp(min, max));
  }

  /// Persists the current (or given) scale after a pinch settles.
  Future<void> commit([double? scale]) async {
    final value = (scale ?? state.valueOrNull ?? defaultScale).clamp(min, max);
    state = AsyncData(value);
    await ref
        .read(appDatabaseProvider)
        .keyValueDao
        .setValue(_key, value.toString());
  }
}
