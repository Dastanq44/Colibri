import '../domain/sync_entity_type.dart';
import '../domain/sync_operation.dart';

/// Pure helpers for translating queued payloads into Supabase row maps. Kept
/// free of Drift/Supabase types so they are easily unit-tested.

/// Our local book ids are 32 hex chars (128 bits). Supabase `books.id` is a
/// uuid, so format the same bytes as a dashed uuid (deterministic, idempotent).
/// Anything already dashed/unknown is returned unchanged.
String localBookIdToUuid(String id) {
  final hex = id.replaceAll('-', '');
  if (hex.length == 32 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
  return id;
}

/// Whether the MVP sync processor can handle this queue item.
bool isSupportedSyncItem(SyncEntityType? type, SyncOperation? op) {
  if (type == null || op == null) return false;
  switch (type) {
    case SyncEntityType.book:
      return op == SyncOperation.create || op == SyncOperation.update;
    case SyncEntityType.bookFile:
      return op == SyncOperation.uploadFile;
    case SyncEntityType.bookshelf:
      return op == SyncOperation.create || op == SyncOperation.update;
    case SyncEntityType.readingProgress:
      return op == SyncOperation.create || op == SyncOperation.update;
    case SyncEntityType.note:
    case SyncEntityType.bookmark:
      // Update-only upserts: every snapshot (including soft-delete
      // tombstones) travels as an update (TASK-1104).
      return op == SyncOperation.update;
    case SyncEntityType.readerSettings:
    case SyncEntityType.fastSettings:
    case SyncEntityType.readingSession:
      return false; // not part of the MVP cloud schema/flow yet
  }
}

String? _nullIfEmpty(Object? value) {
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty ? null : s;
}

Map<String, dynamic> booksRow(String bookUuid, Map<String, dynamic> payload) {
  return <String, dynamic>{
    'id': bookUuid,
    'source_type': 'upload',
    'format': payload['format'],
    'title': payload['title'],
    'language': _nullIfEmpty(payload['language']),
    'is_fast_mode_supported': payload['is_fast_mode_supported'] ?? false,
    'text_ready_status': payload['text_ready_status'] ?? 'pending',
    'rights_scope': 'user_upload',
  };
}

Map<String, dynamic> bookshelfRow(
  String userId,
  String bookUuid,
  Map<String, dynamic> payload,
) {
  return <String, dynamic>{
    'user_id': userId,
    'book_id': bookUuid,
    'status': payload['status'],
    'started_at': payload['started_at'],
    'finished_at': payload['finished_at'],
    'added_at': payload['added_at'],
    'last_opened_at': payload['last_opened_at'],
  };
}

Map<String, dynamic> progressRow(
  String userId,
  String bookUuid,
  Map<String, dynamic> payload,
) {
  return <String, dynamic>{
    'user_id': userId,
    'book_id': bookUuid,
    'locator_type': payload['locator_type'],
    'locator_value': payload['locator_value'],
    'chapter_index': payload['chapter_index'],
    'page_number': payload['page_number'],
    'paragraph_index': payload['paragraph_index'],
    'token_index': payload['token_index'],
    'percent': payload['percent'],
    'mode': payload['mode'],
    'device_id': payload['device_id'],
    'revision': payload['revision'],
    'updated_at': payload['updated_at'],
  };
}

/// Cloud `notes` row from a queued note snapshot. [noteUuid] is the local
/// note id in uuid form; `book_id` is mapped the same way.
Map<String, dynamic> noteRow(
  String userId,
  String noteUuid,
  Map<String, dynamic> payload,
) {
  return <String, dynamic>{
    'id': noteUuid,
    'user_id': userId,
    'book_id': localBookIdToUuid(payload['book_id'] as String),
    'locator_type': payload['locator_type'],
    'locator_value': payload['locator_value'],
    'selected_text': payload['selected_text'],
    'note_text': payload['note_text'],
    'color': payload['color'],
    'created_at': payload['created_at'],
    'updated_at': payload['updated_at'],
    'deleted_at': payload['deleted_at'],
  };
}

/// Cloud `bookmarks` row from a queued bookmark snapshot (see [noteRow]).
Map<String, dynamic> bookmarkRow(
  String userId,
  String bookmarkUuid,
  Map<String, dynamic> payload,
) {
  return <String, dynamic>{
    'id': bookmarkUuid,
    'user_id': userId,
    'book_id': localBookIdToUuid(payload['book_id'] as String),
    'locator_type': payload['locator_type'],
    'locator_value': payload['locator_value'],
    'chapter_index': payload['chapter_index'],
    'paragraph_index': payload['paragraph_index'],
    'token_index': payload['token_index'],
    'label': payload['label'],
    'created_at': payload['created_at'],
    'deleted_at': payload['deleted_at'],
  };
}

Map<String, dynamic> bookFileRow({
  required String userId,
  required String bookUuid,
  required String storagePath,
  required String? checksum,
  required String mimeType,
  required int sizeBytes,
}) {
  return <String, dynamic>{
    'book_id': bookUuid,
    'owner_id': userId,
    'storage_path': storagePath,
    'checksum_sha256': _nullIfEmpty(checksum),
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
    'ingest_status': 'ready',
    'text_extraction_status': 'pending',
  };
}

/// MIME type for a supported book format wire value.
String mimeForFormat(String format) {
  switch (format) {
    case 'epub':
      return 'application/epub+zip';
    case 'pdf':
      return 'application/pdf';
    case 'txt':
    default:
      return 'text/plain';
  }
}

/// Sanitizes a file name for a storage object path (no separators).
String safeStorageName(String fileName) {
  final base = fileName.split(RegExp(r'[\\/]')).last;
  final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return cleaned.isEmpty ? 'book' : cleaned;
}

