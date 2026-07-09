import 'package:colibri/app/localization/generated/app_localizations.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/local/database_providers.dart';
import 'package:colibri/features/reader/fast_mode/domain/fast_mode_settings.dart';
import 'package:colibri/features/reader/settings/application/reader_settings_providers.dart';
import 'package:colibri/features/reader/settings/domain/reader_settings.dart';
import 'package:colibri/features/reader/settings/presentation/reader_settings_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reader settings sheet is scroll-controlled and can fill the screen, so
/// it must always expose an explicit way to dismiss it (a bug report: on iOS
/// it felt un-closable). These tests pin down the close affordance.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        // Feed the sheet static settings so no live Drift stream is opened
        // (a subscribed query stream would leave a pending timer at teardown).
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          readerSettingsProvider
              .overrideWith((ref) => Stream.value(ReaderSettings.defaults())),
          fastModeSettingsProvider
              .overrideWithValue(FastModeSettings.defaults()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const ReaderSettingsSheet(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  // Bounded pumps (not pumpAndSettle): the settings providers are backed by
  // live Drift streams that keep re-scheduling work, so pumpAndSettle never
  // returns. A fixed number of frames is enough to open/close the sheet.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('opens and shows a close button', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    await settle(tester);

    expect(find.byType(ReaderSettingsSheet), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('the close button dismisses the sheet', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.byType(ReaderSettingsSheet), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);

    expect(find.byType(ReaderSettingsSheet), findsNothing);
  });

  testWidgets('presets section shows the seeded Profile A', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    await settle(tester);

    expect(find.text('Profile A'), findsOneWidget);
  });
}
