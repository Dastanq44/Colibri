import 'package:colibri/app/theme/reader_fonts.dart';
import 'package:colibri/app/theme/reader_theme.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/features/reader/settings/data/reader_settings_repository.dart';
import 'package:colibri/features/reader/settings/domain/reading_profile.dart';
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

  test('font family, page animation, haptics and reduced motion round-trip',
      () async {
    // Defaults first.
    var settings = await repo.watchReaderSettings().first;
    expect(settings.fontFamily, ReaderFontFamily.system);
    expect(settings.pageAnimationEnabled, isTrue);
    expect(settings.hapticsEnabled, isTrue);
    expect(settings.reducedMotion, isFalse);

    await repo.setFontFamily(ReaderFontFamily.serif);
    await repo.setPageAnimationEnabled(false);
    await repo.setHapticsEnabled(false);
    await repo.setReducedMotion(true);

    settings = await repo.watchReaderSettings().first;
    expect(settings.fontFamily, ReaderFontFamily.serif);
    expect(settings.pageAnimationEnabled, isFalse);
    expect(settings.hapticsEnabled, isFalse);
    expect(settings.reducedMotion, isTrue);

    final row = await db.settingsDao.getReaderSettings();
    expect(row.fontFamily, 'serif');
    expect(row.pageAnimation, 'none');
    expect(row.hapticsEnabled, isFalse);
    expect(row.reducedMotion, isTrue);
  });

  group('readability profiles', () {
    test('low vision writes near-max text values and suggests dark theme',
        () async {
      await repo.applyProfile(ReadingProfile.lowVision);

      final settings = await repo.watchReaderSettings().first;
      final preset = ReadingProfilePreset.of(ReadingProfile.lowVision);
      expect(settings.fontSize, preset.fontSize);
      expect(settings.lineHeight, preset.lineHeight);
      expect(settings.letterSpacing, preset.letterSpacing);
      expect(settings.fontFamily, preset.fontFamily);
      expect(settings.theme, ReaderThemeVariant.dark);
    });

    test('profiles without a theme suggestion leave the theme alone',
        () async {
      await repo.setTheme(ReaderThemeVariant.sepia);
      await repo.applyProfile(ReadingProfile.highReadability);

      final settings = await repo.watchReaderSettings().first;
      expect(settings.theme, ReaderThemeVariant.sepia);
      expect(settings.fontSize,
          ReadingProfilePreset.of(ReadingProfile.highReadability).fontSize);
    });

    test('user can customize settings after applying a profile', () async {
      await repo.applyProfile(ReadingProfile.dyslexia);
      await repo.setFontSize(20);

      final settings = await repo.watchReaderSettings().first;
      expect(settings.fontSize, 20); // customized
      // The rest of the profile's values remain.
      expect(settings.lineHeight,
          ReadingProfilePreset.of(ReadingProfile.dyslexia).lineHeight);
      expect(settings.letterSpacing,
          ReadingProfilePreset.of(ReadingProfile.dyslexia).letterSpacing);
    });

    test('standard restores the default text values', () async {
      await repo.applyProfile(ReadingProfile.lowVision);
      await repo.applyProfile(ReadingProfile.standard);

      final settings = await repo.watchReaderSettings().first;
      expect(settings.fontSize, 18);
      expect(settings.lineHeight, 1.5);
      expect(settings.letterSpacing, 0);
      expect(settings.fontFamily, ReaderFontFamily.system);
    });
  });
}
