import 'package:colibri/app/localization/generated/app_localizations.dart';
import 'package:colibri/features/home/presentation/home_screen.dart';
import 'package:colibri/features/library/application/library_providers.dart';
import 'package:colibri/features/library/domain/library_book.dart';
import 'package:colibri/shared/models/book_format.dart';
import 'package:colibri/shared/models/bookshelf_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryBook _book(
  String id, {
  DateTime? opened,
  double percent = 0,
  BookShelfStatus status = BookShelfStatus.reading,
}) =>
    LibraryBook(
      id: id,
      title: 'Book $id',
      authorDisplay: 'Author $id',
      format: BookFormat.txt,
      status: status,
      percent: percent,
      isFastModeSupported: true,
      lastOpenedAt: opened,
    );

Widget _harness(List<LibraryBook> books) => ProviderScope(
      overrides: <Override>[
        myBooksProvider.overrideWith((ref) => Stream.value(books)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(),
      ),
    );

void main() {
  testWidgets('shows the empty state with an import CTA when no books',
      (tester) async {
    await tester.pumpWidget(_harness(const <LibraryBook>[]));
    await tester.pumpAndSettle();

    expect(find.text('Start your library'), findsOneWidget);
    expect(find.text('Import book'), findsOneWidget);
    expect(find.text('Continue reading'), findsNothing);
  });

  testWidgets('shows up to three most recently opened books, newest first',
      (tester) async {
    final now = DateTime(2026, 7, 7);
    await tester.pumpWidget(_harness(<LibraryBook>[
      _book('old', opened: now.subtract(const Duration(days: 3))),
      _book('newest', opened: now, percent: 42),
      _book('never-opened'),
      _book('mid', opened: now.subtract(const Duration(days: 1))),
      _book('oldest', opened: now.subtract(const Duration(days: 9))),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('Book newest'), findsOneWidget);
    expect(find.text('Book mid'), findsOneWidget);
    expect(find.text('Book old'), findsOneWidget);
    // Cap of three: the fourth-most-recent and never-opened books are absent.
    expect(find.text('Book oldest'), findsNothing);
    expect(find.text('Book never-opened'), findsNothing);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('finished and abandoned books are not "continue reading"',
      (tester) async {
    final now = DateTime(2026, 7, 7);
    await tester.pumpWidget(_harness(<LibraryBook>[
      _book('done', opened: now, status: BookShelfStatus.finished),
      _book('dropped', opened: now, status: BookShelfStatus.abandoned),
      _book('active', opened: now.subtract(const Duration(days: 1))),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Book active'), findsOneWidget);
    expect(find.text('Book done'), findsNothing);
    expect(find.text('Book dropped'), findsNothing);
  });

  testWidgets('shows goal card and quick actions when books exist',
      (tester) async {
    await tester
        .pumpWidget(_harness(<LibraryBook>[_book('a', opened: DateTime(2026))]));
    await tester.pumpAndSettle();

    expect(find.text('Daily goal'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Import book'), findsOneWidget);
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('My Books'), findsOneWidget);
  });
}
