import 'package:colibri/app/localization/generated/app_localizations.dart';
import 'package:colibri/app/router/app_router.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/local/database_providers.dart';
import 'package:colibri/data/repositories/analytics_repository.dart';
import 'package:colibri/features/onboarding/application/onboarding_providers.dart';
import 'package:colibri/features/onboarding/data/onboarding_repository.dart';
import 'package:colibri/features/onboarding/presentation/onboarding_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('OnboardingRepository', () {
    test('flag round-trips and defaults to false', () async {
      final repo = OnboardingRepository(db);
      expect(await repo.isCompleted(), isFalse);

      await repo.markCompleted();
      expect(await repo.isCompleted(), isTrue);
    });
  });

  group('OnboardingScreen', () {
    Widget harness() {
      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: <RouteBase>[
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) =>
                const Scaffold(body: Text('home-stub')),
          ),
        ],
      );
      return ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    testWidgets('walks all three pages and completes on Start', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Two ways to read'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Fast mode'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Control rotation'), findsOneWidget);
      await tester.tap(find.text('Start reading'));
      await tester.pumpAndSettle();

      expect(find.text('home-stub'), findsOneWidget);
      expect(await OnboardingRepository(db).isCompleted(), isTrue);
    });

    testWidgets('skip persists the flag and lands on home', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('home-stub'), findsOneWidget);
      expect(await OnboardingRepository(db).isCompleted(), isTrue);
    });

    testWidgets('does not overflow at landscape phone sizes', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      // A RenderFlex overflow would surface as a FlutterError here.
      expect(tester.takeException(), isNull);
      expect(find.text('Two ways to read'), findsOneWidget);
    });
  });

  group('router redirect', () {
    testWidgets(
        'completed users can still open /onboarding explicitly (no bounce)',
        (tester) async {
      await OnboardingRepository(db).markCompleted();

      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          analyticsRepositoryProvider
              .overrideWithValue(const NoOpAnalyticsRepository()),
        ],
      );
      addTearDown(container.dispose);
      // Settle the flag before the router's first pass, as the app does.
      await container.read(onboardingCompletedProvider.future);
      final router = container.read(goRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.push('/onboarding');
      await tester.pumpAndSettle();

      expect(find.text('Two ways to read'), findsOneWidget);
    });
  });
}
