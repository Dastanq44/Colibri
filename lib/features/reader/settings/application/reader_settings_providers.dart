import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/local/database_providers.dart';
import '../../fast_mode/domain/fast_mode_settings.dart';
import '../data/reader_settings_repository.dart';
import '../domain/reader_settings.dart';

final readerSettingsRepositoryProvider = Provider<ReaderSettingsRepository>(
  (ref) => ReaderSettingsRepository(ref.watch(appDatabaseProvider)),
);

/// Persisted normal-reader settings (defaults until the first row loads).
final readerSettingsProvider = StreamProvider<ReaderSettings>(
  (ref) => ref.watch(readerSettingsRepositoryProvider).watchReaderSettings(),
);

final _fastRowSettingsProvider = StreamProvider<FastModeSettings>(
  (ref) => ref.watch(readerSettingsRepositoryProvider).watchFastSettings(),
);

/// Fast-mode settings combined with the speed-lock flag from reader settings.
final fastModeSettingsProvider = Provider<FastModeSettings>((ref) {
  final fast =
      ref.watch(_fastRowSettingsProvider).valueOrNull ?? FastModeSettings.defaults();
  final speedLock =
      ref.watch(readerSettingsProvider).valueOrNull?.speedLockEnabled ?? false;
  return fast.copyWith(speedLockEnabled: speedLock);
});
