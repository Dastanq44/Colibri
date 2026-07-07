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

    // Notes/bookmarks travel as update-only upsert snapshots (Phase 11).
    expect(isSupportedSyncItem(SyncEntityType.note, SyncOperation.update),
        isTrue);
    expect(isSupportedSyncItem(SyncEntityType.bookmark, SyncOperation.update),
        isTrue);
    expect(isSupportedSyncItem(SyncEntityType.note, SyncOperation.create),
        isFalse);
    expect(isSupportedSyncItem(SyncEntityType.bookmark, SyncOperation.delete),
        isFalse);
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

  test('noteRow maps ids to uuids and carries the tombstone', () {
    final row = noteRow(
      'u1',
      '01234567-89ab-cdef-0123-456789abcdef',
      <String, dynamic>{
        'book_id': 'fedcba9876543210fedcba9876543210',
        'locator_type': 'text_offset',
        'locator_value': '1500',
        'note_text': 'hi',
        'deleted_at': '2026-07-07T00:00:00.000Z',
      },
    );
    expect(row['id'], '01234567-89ab-cdef-0123-456789abcdef');
    expect(row['user_id'], 'u1');
    expect(row['book_id'], 'fedcba98-7654-3210-fedc-ba9876543210');
    expect(row['note_text'], 'hi');
    expect(row['deleted_at'], '2026-07-07T00:00:00.000Z');
  });

  test('bookmarkRow maps ids to uuids and locator detail', () {
    final row = bookmarkRow(
      'u1',
      '01234567-89ab-cdef-0123-456789abcdef',
      <String, dynamic>{
        'book_id': 'fedcba9876543210fedcba9876543210',
        'locator_type': 'text_offset',
        'locator_value': '1500',
        'chapter_index': 2,
        'label': 'here',
        'deleted_at': null,
      },
    );
    expect(row['id'], '01234567-89ab-cdef-0123-456789abcdef');
    expect(row['book_id'], 'fedcba98-7654-3210-fedc-ba9876543210');
    expect(row['chapter_index'], 2);
    expect(row['label'], 'here');
    expect(row['deleted_at'], isNull);
  });
}
