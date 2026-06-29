import 'package:colibri/features/sync/data/sync_payloads.dart';
import 'package:colibri/features/sync/domain/sync_entity_type.dart';
import 'package:colibri/features/sync/domain/sync_operation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('localBookIdToUuid', () {
    test('formats 32 hex chars as a dashed uuid', () {
      expect(
        localBookIdToUuid('0123456789abcdef0123456789abcdef'),
        '01234567-89ab-cdef-0123-456789abcdef',
      );
    });

    test('passes a dashed uuid through unchanged', () {
      const uuid = '01234567-89ab-cdef-0123-456789abcdef';
      expect(localBookIdToUuid(uuid), uuid);
    });
  });

  test('isSupportedSyncItem covers the MVP set only', () {
    expect(isSupportedSyncItem(SyncEntityType.book, SyncOperation.create), isTrue);
    expect(isSupportedSyncItem(SyncEntityType.bookFile, SyncOperation.uploadFile),
        isTrue);
    expect(
        isSupportedSyncItem(SyncEntityType.bookshelf, SyncOperation.update), isTrue);
    expect(
        isSupportedSyncItem(
            SyncEntityType.readingProgress, SyncOperation.update),
        isTrue);
    expect(
        isSupportedSyncItem(SyncEntityType.readerSettings, SyncOperation.update),
        isFalse);
    expect(isSupportedSyncItem(null, null), isFalse);
  });

  test('booksRow marks upload source + user_upload rights', () {
    final row = booksRow('book-uuid', <String, dynamic>{
      'format': 'epub',
      'title': 'War and Peace',
      'language': 'ru',
      'is_fast_mode_supported': true,
      'text_ready_status': 'ready',
    });
    expect(row['id'], 'book-uuid');
    expect(row['source_type'], 'upload');
    expect(row['rights_scope'], 'user_upload');
    expect(row['title'], 'War and Peace');
  });

  test('progressRow injects user + book id and maps locator fields', () {
    final row = progressRow('u1', 'book-uuid', <String, dynamic>{
      'locator_type': 'text_offset',
      'locator_value': '42',
      'percent': 12.5,
      'mode': 'fast',
      'device_id': 'd1',
      'revision': 3,
      'updated_at': 't',
    });
    expect(row['user_id'], 'u1');
    expect(row['book_id'], 'book-uuid');
    expect(row['locator_type'], 'text_offset');
    expect(row['percent'], 12.5);
    expect(row['mode'], 'fast');
  });
}
