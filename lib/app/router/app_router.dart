import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_route_observer.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/book_detail/presentation/book_detail_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/import/presentation/import_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/onboarding/application/onboarding_providers.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'unknown_route_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Provides the app's [GoRouter]. First launch is gated to onboarding; the
/// app root shows a splash until the onboarding flag resolves, so the
/// redirect below always sees a settled value.
final goRouterProvider = Provider<GoRouter>((ref) {
  final analytics = ref.watch(analyticsRepositoryProvider);
  // A navigator accepts an observer only once: one for the root, one per
  // tab branch (see the shell below).
  AnalyticsRouteObserver observer() => AnalyticsRouteObserver(analytics);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    observers: <NavigatorObserver>[observer()],
    redirect: (context, state) {
      // First-launch gate only: force onboarding until completed. Completed
      // users may still open /onboarding explicitly (e.g. from Home) — no
      // bounce back, or that entry point would be rewritten mid-push.
      // On a load error, err toward not blocking the app (skip onboarding).
      final completed =
          ref.read(onboardingCompletedProvider).valueOrNull ?? true;
      if (!completed && state.matchedLocation != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }
      return null;
    },
    routes: <RouteBase>[
      // --- Top-level / pushed routes ---
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRoutes.onboardingName,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        name: AppRoutes.authName,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.importBook,
        name: AppRoutes.importName,
        builder: (context, state) => const ImportScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.settingsName,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        name: AppRoutes.editProfileName,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookDetailPath,
        name: AppRoutes.bookDetailName,
        builder: (context, state) => BookDetailScreen(
          bookId: state.pathParameters['bookId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.readerPath,
        name: AppRoutes.readerName,
        builder: (context, state) => ReaderScreen(
          bookId: state.pathParameters['bookId'] ?? '',
        ),
      ),

      // --- Bottom-tab shell ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            observers: <NavigatorObserver>[observer()],
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                name: AppRoutes.homeName,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: <NavigatorObserver>[observer()],
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.catalog,
                name: AppRoutes.catalogName,
                builder: (context, state) => const CatalogScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: <NavigatorObserver>[observer()],
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.library,
                name: AppRoutes.libraryName,
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: <NavigatorObserver>[observer()],
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.profile,
                name: AppRoutes.profileName,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        UnknownRouteScreen(location: state.uri.toString()),
  );
});
