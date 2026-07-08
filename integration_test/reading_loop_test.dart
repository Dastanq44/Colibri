import 'dart:io';

import 'package:colibri/app/app.dart';
import 'package:colibri/core/config/app_config.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/local/database_providers.dart';
import 'package:colibri/data/remote/supabase_client_provider.dart';
import 'package:colibri/features/onboarding/data/onboarding_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The MVP completion loop (plan §4 / TASK-1603): open a book, page forward,
/// rotate into fast mode, change WPM, rotate back, exit, reopen, resume.
///
/// Runs the real app (real router, database wiring, reader engine) against an
/// in-memory database and a seeded TXT book, with no backend. Run on a
/// device/simulator via `flutter test integration_test -d <device>`; it also
/// passes on the host VM via plain `flutter test integration_test`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const portrait = Size(390, 844);
  const landscape = Size(844, 390);

  testWidgets('import → read → fast mode → WPM → return → resume', (tester) async {
    tester.view.physicalSize = portrait;
    tester.view.devicePixelRatio = 1.0;
    // Neutralize the host device's notch/home-bar insets: they arrive in
    // physical pixels and would skew layout under the faked 1.0 ratio.
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    // --- Seed: a TXT book on disk + local records (import result shape). ---
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('colibri_itest');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/loop.txt');
    file.writeAsStringSync(
      List<String>.generate(4000, (i) => 'word$i').join(' '),
    );
    await db.booksDao.upsertBook(LocalBooksCompanion.insert(
      id: 'itest-book',
      sourceType: 'upload',
      format: 'txt',
      title: 'Loop Test Book',
      fileLocalPath: file.path,
    ));
    await db.bookshelfDao.upsertEntry(LocalBookshelfCompanion.insert(
      bookId: 'itest-book',
      status: 'reading',
    ));
    await OnboardingRepository(db).markCompleted(); // skip first-launch gate

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          appConfigProvider.overrideWithValue(AppConfig.fromEnvironment()),
          supabaseClientProvider.overrideWithValue(null),
        ],
        child: const ColibriApp(),
      ),
    );
    await tester.pumpAndSettle();

    // --- My Books tab → open the book. ---
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('My Books'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loop Test Book'));
    await tester.pumpAndSettle();
    expect(find.textContaining('word0'), findsOneWidget); // page 1 visible

    // --- Page forward several times (advance well past the first page). ---
    for (var i = 0; i < 6; i++) {
      await tester.tapAt(Offset(portrait.width * 0.8, 400));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('word0 '), findsNothing); // moved off page 1
    final afterPage = await db.progressDao.getByBookId('itest-book');
    expect(afterPage, isNotNull);
    expect(afterPage!.pageNumber, greaterThan(0)); // advanced + saved
    final advancedPercent = afterPage.percent;
    expect(advancedPercent, greaterThan(0));

    // --- Rotate to landscape → fast mode (after stability threshold). ---
    tester.view.physicalSize = landscape;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700)); // threshold
    await tester.pumpAndSettle();
    expect(find.textContaining('WPM'), findsWidgets); // fast mode bottom bar
    expect(find.text('275 WPM'), findsOneWidget); // default WPM

    // --- Right tap = +25 WPM with feedback. ---
    await tester.tapAt(Offset(landscape.width * 0.85, 150));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('300 WPM'), findsOneWidget);
    // Transient +25 feedback clears on its own.
    await tester.pump(const Duration(milliseconds: 800));
    // TEMP: hold the fast-mode screen for an external screenshot.
    await tester.pump(const Duration(seconds: 5));

    // --- Rotate back to portrait → normal reader, position kept. ---
    tester.view.physicalSize = portrait;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('300 WPM'), findsNothing); // fast UI gone
    expect(find.textContaining('%'), findsWidgets); // reader bottom bar

    // --- Exit the reader; progress + WPM persisted. ---
    await tester.pageBack();
    await tester.pumpAndSettle();
    final saved = await db.progressDao.getByBookId('itest-book');
    expect(saved, isNotNull);
    expect(saved!.percent, greaterThan(0));
    expect((await db.settingsDao.getFastSettings()).defaultWpm, 300);

    // --- Reopen: resumes near the saved offset, not back at page 1. ---
    await tester.tap(find.text('Loop Test Book'));
    await tester.pumpAndSettle();
    expect(find.textContaining('word0 '), findsNothing);

    // Sessions were recorded for the reading stretch (normal + fast).
    await tester.pageBack();
    await tester.pumpAndSettle();
    final sessions = await db.sessionsDao.getForBook('itest-book');
    expect(sessions, isNotEmpty);
  });
}
