import 'dart:io';

import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/repositories/local_library_repository.dart';
import 'package:colibri/features/import/data/file_storage_service.dart';
import 'package:colibri/features/library/domain/library_book.dart';
import 'package:colibri/shared/models/bookshelf_status.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late LocalLibraryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('colibri_lib');
    repo = LocalLibraryRepository(db, FileStorageService(baseDirectory: tmp));
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> seedBook(String id, {String status = 'reading'}) async {
    await db.booksDao.upsertBook(
      LocalBooksCompanion.insert(
        id: id,
        sourceType: 'upload',
        format: 'txt',
        title: 'Book $id',
        fileLocalPath: '/tmp/$id.txt',
      ),
    );
    await db.bookshelfDao.upsertEntry(
      LocalBookshelfCompanion.insert(bookId: id, status: status),
    );
  }

  List<LibraryBook> unwrap(Result<List<LibraryBook>> r) => switch (r) {
        Ok(value: final v) => v,
        Err() => <LibraryBook>[],
      };

  test('imported/local book appears in getMyBooks', () async {
    await seedBook('b1');

    final books = unwrap(await repo.getMyBooks());

    expect(books, hasLength(1));
    expect(books.single.title, 'Book b1');
    expect(books.single.status, BookShelfStatus.reading);
    expect(books.single.percent, 0);
  });

  test('updateBookStatus changes the bookshelf status', () async {
    await seedBook('b1');

    await repo.updateBookStatus('b1', BookShelfStatus.finished.wire);

    final books = unwrap(await repo.getMyBooks());
    expect(books.single.status, BookShelfStatus.finished);
  });
}
