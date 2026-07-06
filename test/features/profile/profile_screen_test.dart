import 'dart:async';

import 'package:colibri/app/localization/generated/app_localizations.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/remote/supabase_client_provider.dart';
import 'package:colibri/data/repositories/profile_repository.dart';
import 'package:colibri/features/auth/application/auth_providers.dart';
import 'package:colibri/features/auth/domain/auth_user.dart';
import 'package:colibri/features/profile/application/profile_providers.dart';
import 'package:colibri/features/profile/domain/profile.dart';
import 'package:colibri/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake repository whose [updateDisplayName] completes only when the test
/// resolves [updateCompleter], so tests can control the in-flight window.
class _FakeProfileRepository implements ProfileRepository {
  final Completer<Result<void>> updateCompleter = Completer<Result<void>>();

  @override
  Future<Result<Profile>> getCurrentProfile() async =>
      const Ok(Profile(id: 'u1', displayName: 'Old Name'));

  @override
  Future<Result<void>> ensureProfileForCurrentUser() async => const Ok(null);

  @override
  Future<Result<void>> updateDisplayName(String displayName) =>
      updateCompleter.future;

  @override
  Future<Result<void>> updateLocale(String locale) async => const Ok(null);

  @override
  Future<Result<void>> updateGoals({
    int? goalDailyMinutes,
    int? goalBooksYear,
  }) async =>
      const Ok(null);
}

void main() {
  testWidgets('Profile shows signed-out state with a sign-in CTA', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          // No backend -> signed out.
          supabaseClientProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You are signed out'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('Edit name tolerates sign-out while the update is in flight',
      (tester) async {
    final repo = _FakeProfileRepository();
    final signedIn = StateProvider<bool>((ref) => true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          isSignedInProvider.overrideWith((ref) => ref.watch(signedIn)),
          currentUserProvider.overrideWithValue(
            const AuthUser(id: 'u1', email: 'u@example.com'),
          ),
          profileRepositoryProvider.overrideWithValue(repo),
          backendConfiguredProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the edit-name dialog and submit a new name.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New Name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle(); // dialog closed; update awaits the repo

    // Sign out while the update is in flight: the signed-in body unmounts.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfileScreen)),
      listen: false,
    );
    container.read(signedIn.notifier).state = false;
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    // Completing the update after unmount must not touch ref/context.
    repo.updateCompleter.complete(const Ok(null));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
