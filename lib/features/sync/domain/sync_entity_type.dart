/// The kind of local entity a sync-queue item refers to. [wire] is stored in
/// `sync_queue.entity_type`.
enum SyncEntityType {
  book('book'),
  bookFile('book_file'),
  bookshelf('bookshelf'),
  readingProgress('reading_progress'),
  readerSettings('reader_settings'),
  fastSettings('fast_settings'),
  note('note'),
  bookmark('bookmark'),
  readingSession('reading_session');

  const SyncEntityType(this.wire);

  final String wire;

  static SyncEntityType? fromWire(String value) {
    for (final type in SyncEntityType.values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}
