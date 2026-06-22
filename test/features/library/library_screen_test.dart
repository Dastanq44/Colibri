import 'package:colibri/app/localization/generated/app_localizations.dart';
import 'package:colibri/features/library/application/library_providers.dart';
import 'package:colibri/features/library/domain/library_book.dart';
import 'package:colibri/features/library/presentation/library_screen.dart';
import 'package:colibri/shared/models/book_format.dart';
import 'package:colibri/shared/models/bookshelf_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LibraryScreen(),
      ),
    );

void main() {
  testWidgets('shows the empty state when there are no books', (tester) async {
    await tester.pumpWidget(_harness(<Override>[
      myBooksProvider.overrideWith((ref) => Stream.value(const <LibraryBook>[])),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('No books yet'), findsOneWidget);
  });

  testWidgets('shows an imported book title', (tester) async {
    const book = LibraryBook(
      id: 'b1',
      title: 'War and Peace',
      authorDisplay: '',
      format: BookFormat.txt,
      status: BookShelfStatus.reading,
      percent: 0,
      isFastModeSupported: true,
    );

    await tester.pumpWidget(_harness(<Override>[
      myBooksProvider.overrideWith((ref) => Stream.value(<LibraryBook>[book])),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('War and Peace'), findsOneWidget);
  });
}
