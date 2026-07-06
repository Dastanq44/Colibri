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
import 'package:colibri/features/sync/data/local_sync_queue_repository.dart';
import 'package:colibri/shared/models/book_format.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates a mid-copy I/O failure (e.g. disk full): the destination
/// directory and a partial file exist, then the copy throws.
class _FailingCopyStorage extends FileStorageService {
  _FailingCopyStorage(Directory base) : super(baseDirectory: base);

  @override
  Future<String> copyIntoBookStorage({
    required String bookId,
    required String sourcePath,
    required String fileName,
  }) async {
    await super.copyIntoBookStorage(
        bookId: bookId, sourcePath: sourcePath, fileName: fileName);
    throw const FileSystemException('disk full');
  }
}

class _ThrowingDeviceIdService extends DeviceIdService {
  _ThrowingDeviceIdService(super.keyValueDao);

  @override
  Future<String> getOrCreate() async => throw Exception('device id failed');
}

class _ThrowingSyncQueue extends LocalSyncQueueRepository {
  _ThrowingSyncQueue(super.db);

  @override
  Future<void> enqueueBookFileUpload(String bookId) async =>
      throw Exception('enqueue failed');
}

void main() {
  late AppDatabase db;
  late Directory tmp;
  late LocalImportRepository repo;

  LocalImportRepository buildRepo({
    FileStorageService? storage,
    DeviceIdService? deviceIdService,
    LocalSyncQueueRepository? syncQueue,
  }) {
    return LocalImportRepository(
      db: db,
      storage: storage ?? FileStorageService(baseDirectory: tmp),
      checksum: const ChecksumService(),
      validator: const BookFileValidator(),
      metadata: const BookMetadataService(),
      deviceIdService: deviceIdService ?? DeviceIdService(db.keyValueDao),
      syncQueue: syncQueue ?? LocalSyncQueueRepository(db),
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('colibri_import');
    repo = buildRepo();
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

    // Import enqueues cloud sync work.
    final queued = (await db.syncQueueDao.getAll())
        .map((e) => '${e.entityType}:${e.operation}')
        .toSet();
    expect(
      queued,
      containsAll(<String>[
        'book:create',
        'book_file:upload_file',
        'bookshelf:create',
      ]),
    );
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

  test('rejects zero-byte files as empty, never as duplicates', () async {
    final first = await repo.importPickedFile(writeTxt('a.txt', ''));
    // A second, different empty file must not hit the checksum duplicate
    // check (all empty files share one SHA-256).
    final second = await repo.importPickedFile(writeTxt('b.txt', ''));

    expect((first as Err<ImportedBook>).failure, isA<EmptyBookFailure>());
    expect((second as Err<ImportedBook>).failure, isA<EmptyBookFailure>());
    expect(await db.booksDao.getAll(), isEmpty);
  });

  test('removes partially copied files when the copy fails', () async {
    final failing = buildRepo(storage: _FailingCopyStorage(tmp));
    final result = await failing.importPickedFile(writeTxt('a.txt', 'hello'));

    expect((result as Err<ImportedBook>).failure, isA<StorageFailure>());
    final booksRoot = Directory('${tmp.path}/books');
    expect(
      !booksRoot.existsSync() || booksRoot.listSync().isEmpty,
      isTrue,
      reason: 'no orphaned books/<bookId>/ folder may remain',
    );
  });

  test('removes copied files when a step after the copy fails', () async {
    final failing =
        buildRepo(deviceIdService: _ThrowingDeviceIdService(db.keyValueDao));
    final result = await failing.importPickedFile(writeTxt('a.txt', 'hello'));

    expect((result as Err<ImportedBook>).failure, isA<UnknownFailure>());
    final booksRoot = Directory('${tmp.path}/books');
    expect(!booksRoot.existsSync() || booksRoot.listSync().isEmpty, isTrue);
    expect(await db.booksDao.getAll(), isEmpty);
  });

  test('rolls back the whole import when a sync enqueue fails', () async {
    final failing = buildRepo(syncQueue: _ThrowingSyncQueue(db));
    final result = await failing.importPickedFile(writeTxt('a.txt', 'hello'));

    expect(result, isA<Err<ImportedBook>>());
    // Entity rows and outbox rows commit atomically: nothing was saved, so a
    // retry cannot report a phantom duplicate.
    expect(await db.booksDao.getAll(), isEmpty);
    expect(await db.syncQueueDao.getAll(), isEmpty);
    final booksRoot = Directory('${tmp.path}/books');
    expect(!booksRoot.existsSync() || booksRoot.listSync().isEmpty, isTrue);

    // The same file then imports cleanly with a working sync queue.
    final retry = await repo.importPickedFile(writeTxt('a.txt', 'hello'));
    expect(retry, isA<Ok<ImportedBook>>());
    expect((await db.syncQueueDao.getAll()).length, 3);
  });
}
