import 'dart:async';

import 'package:colibri/app/localization/generated/app_localizations.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/local/database_providers.dart';
import 'package:colibri/data/remote/supabase_client_provider.dart';
import 'package:colibri/data/repositories/profile_repository.dart';
import 'package:colibri/features/auth/application/auth_providers.dart';
import 'package:colibri/features/auth/domain/auth_user.dart';
import 'package:colibri/features/library/application/library_providers.dart';
import 'package:colibri/features/library/domain/library_book.dart';
import 'package:colibri/features/profile/application/profile_providers.dart';
import 'package:colibri/features/profile/domain/profile.dart';
import 'package:colibri/features/profile/presentation/edit_profile_screen.dart';
import 'package:colibri/features/profile/presentation/profile_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
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

  testWidgets('Edit profile save tolerates unmount while the update is in flight',
      (tester) async {
    final repo = _FakeProfileRepository();
    late AppDatabase db;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(
            const AuthUser(id: 'u1', email: 'u@example.com'),
          ),
          profileRepositoryProvider.overrideWithValue(repo),
          myBooksProvider.overrideWith(
              (ref) => Stream.value(const <LibraryBook>[])),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EditProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter a new name and hit Done; the update awaits the repo.
    await tester.enterText(find.byType(CupertinoTextField).first, 'New Name');
    await tester.tap(find.text('Done'));
    await tester.pump();

    // Unmount the screen while the update is in flight.
    await tester.pumpWidget(const SizedBox());
    repo.updateCompleter.complete(const Ok(null));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
