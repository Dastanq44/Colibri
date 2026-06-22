import 'dart:io';

import 'package:colibri/core/errors/failures.dart';
import 'package:colibri/core/platform/device_id_service.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/repositories/local_import_repository.dart';
import 'package:colibri/features/import/data/book_file_validator.dart';
import 'package:colibri/features/import/data/book_metadata_service.dart';
import 'package:colibri/features/import/data/checksum_service.dart';
import 'package:colibri/features/import/data/file_storage_service.dart';
import 'package:colibri/features/import/domain/import_preview.dart';
import 'package:colibri/features/import/domain/imported_book.dart';
import 'package:colibri/shared/models/book_format.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late LocalImportRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('colibri_import');
    repo = LocalImportRepository(
      db: db,
      storage: FileStorageService(baseDirectory: tmp),
      checksum: const ChecksumService(),
      validator: const BookFileValidator(),
      metadata: const BookMetadataService(),
      deviceIdService: DeviceIdService(db.keyValueDao),
    );
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  ImportPreview writeTxt(String name, String content) {
    final file = File('${tmp.path}/$name')..writeAsStringSync(content);
    return ImportPreview(
      path: file.path,
      fileName: name,
      extension: 'txt',
      sizeBytes: file.lengthSync(),
      format: BookFormat.txt,
    );
  }

  test('imports a TXT file into the local database', () async {
    final result = await repo.importPickedFile(writeTxt('My Book.txt', 'hello'));

    final book = switch (result) {
      Ok(value: final b) => b,
      Err(failure: final f) => fail('expected success, got $f'),
    };

    expect(book.title, 'My Book');
    expect(book.format, BookFormat.txt);

    final stored = await db.booksDao.getById(book.bookId);
    expect(stored, isNotNull);
    expect(stored!.format, 'txt');
    expect(await db.bookshelfDao.getByBookId(book.bookId), isNotNull);
    expect(await db.progressDao.getByBookId(book.bookId), isNotNull);
    // The file was copied into app storage.
    expect(File(stored.fileLocalPath).existsSync(), isTrue);
  });

  test('rejects a duplicate file (same content)', () async {
    await repo.importPickedFile(writeTxt('a.txt', 'same content'));
    final result = await repo.importPickedFile(writeTxt('b.txt', 'same content'));

    expect(result, isA<Err<ImportedBook>>());
    expect((result as Err<ImportedBook>).failure, isA<DuplicateFailure>());
  });

  test('rejects an unsupported file type', () async {
    final preview = ImportPreview(
      path: '${tmp.path}/x.docx',
      fileName: 'x.docx',
      extension: 'docx',
      sizeBytes: 10,
    );
    final result = await repo.importPickedFile(preview);

    expect((result as Err<ImportedBook>).failure, isA<UnsupportedFormatFailure>());
  });
}
