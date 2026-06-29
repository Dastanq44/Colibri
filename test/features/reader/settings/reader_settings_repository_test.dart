import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/features/reader/settings/data/reader_settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ReaderSettingsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ReaderSettingsRepository(db);
  });

  tearDown(() => db.close());

  test('defaults are seeded on first read', () async {
    final reader = await db.settingsDao.getReaderSettings();
    expect(reader.modeLockEnabled, isFalse);
    expect(reader.speedLockEnabled, isFalse);
    expect(reader.fontSize, 18);

    final fast = await db.settingsDao.getFastSettings();
    expect(fast.defaultWpm, 275);
    expect(fast.showAdjacentContext, isTrue);
  });

  test('mode lock, speed lock, font size, WPM and adjacent context persist',
      () async {
    await repo.setModeLock(true);
    await repo.setSpeedLock(true);
    await repo.setFontSize(22);
    await repo.setDefaultWpm(350);
    await repo.setShowAdjacentContext(false);

    final reader = await db.settingsDao.getReaderSettings();
    expect(reader.modeLockEnabled, isTrue);
    expect(reader.speedLockEnabled, isTrue);
    expect(reader.fontSize, 22);

    final fast = await db.settingsDao.getFastSettings();
    expect(fast.defaultWpm, 350);
    expect(fast.showAdjacentContext, isFalse);
  });

  test('watchReaderSettings emits the persisted values', () async {
    await repo.setFontSize(24);
    final settings = await repo.watchReaderSettings().first;
    expect(settings.fontSize, 24);
  });
}
