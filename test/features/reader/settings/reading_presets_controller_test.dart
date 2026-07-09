import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/local/database_providers.dart';
import 'package:colibri/features/reader/settings/application/reading_presets_controller.dart';
import 'package:colibri/features/reader/settings/domain/reader_settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: <Override>[
      appDatabaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);
  });

  Future<ReadingPresetsState> load() =>
      container.read(readingPresetsProvider.future);

  test('first run seeds Profile A from current settings and remembers it',
      () async {
    final state = await load();
    expect(state.presets, hasLength(1));
    expect(state.presets.single.letter, 'A');
    expect(state.activeId, state.presets.single.id);
  });

  test('add creates the first unused letter, remove keeps names', () async {
    await load();
    final controller = container.read(readingPresetsProvider.notifier);
    final settings = ReaderSettings.defaults();

    await controller.addPreset(settings); // B
    await controller.addPreset(settings); // C
    var state = container.read(readingPresetsProvider).requireValue;
    expect(state.presets.map((p) => p.letter), <String>['A', 'B', 'C']);
    expect(state.active!.letter, 'C');

    // Remove active (C is active after creation) -> select B? No: first
    // remaining. Select B explicitly, remove it, names keep.
    await controller.select(state.presets[1].id); // B active
    await controller.removeActive();
    state = container.read(readingPresetsProvider).requireValue;
    expect(state.presets.map((p) => p.letter), <String>['A', 'C']);

    // Next add reuses the freed letter B.
    await controller.addPreset(settings);
    state = container.read(readingPresetsProvider).requireValue;
    expect(state.presets.map((p) => p.letter), <String>['A', 'C', 'B']);
  });

  test('max six presets; removing the last one is refused', () async {
    await load();
    final controller = container.read(readingPresetsProvider.notifier);
    final settings = ReaderSettings.defaults();
    for (var i = 0; i < 10; i++) {
      await controller.addPreset(settings);
    }
    var state = container.read(readingPresetsProvider).requireValue;
    expect(state.presets, hasLength(kMaxReadingPresets));

    // Remove down to one; the final removeActive is a no-op.
    for (var i = 0; i < 10; i++) {
      await controller.removeActive();
    }
    state = container.read(readingPresetsProvider).requireValue;
    expect(state.presets, hasLength(1));
  });
}
