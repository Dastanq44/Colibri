import 'package:colibri/data/local/app_database.dart';
// Only `Value` is needed here; avoid clashing with flutter_test matchers.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('SettingsDao reader settings', () {
    test('loads sensible defaults on first read', () async {
      final s = await db.settingsDao.getReaderSettings();

      expect(s.theme, 'light');
      expect(s.fontSize, 18);
      expect(s.lineHeight, 1.5);
      expect(s.letterSpacing, 0);
      expect(s.modeLockEnabled, isFalse);
      expect(s.speedLockEnabled, isFalse);
      expect(s.autoFastModeEnabled, isTrue);
      expect(s.reducedMotion, isFalse);
      expect(s.locale, 'ru-RU');
      expect(s.pageTurnDirection, 'ltr');
    });

    test('updates only the provided fields', () async {
      await db.settingsDao.getReaderSettings(); // seed defaults

      await db.settingsDao.updateReaderSettings(
        const LocalReaderSettingsCompanion(
          theme: Value('dark'),
          fontSize: Value(22),
        ),
      );

      final s = await db.settingsDao.getReaderSettings();
      expect(s.theme, 'dark');
      expect(s.fontSize, 22);
      // Untouched fields keep their defaults.
      expect(s.locale, 'ru-RU');
      expect(s.lineHeight, 1.5);
    });
  });

  group('SettingsDao fast settings', () {
    test('loads fast-mode defaults on first read', () async {
      final f = await db.settingsDao.getFastSettings();

      expect(f.defaultWpm, 275);
      expect(f.minWpm, 150);
      expect(f.maxWpm, 700);
      expect(f.wpmStep, 25);
      expect(f.showAdjacentContext, isTrue);
      expect(f.chunkMode, 'word');
    });
  });
}
