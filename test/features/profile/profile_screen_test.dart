import 'package:colibri/app/localization/generated/app_localizations.dart';
import 'package:colibri/data/remote/supabase_client_provider.dart';
import 'package:colibri/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
