/// The operation a sync-queue item performs. [wire] is stored in
/// `sync_queue.operation`.
enum SyncOperation {
  create('create'),
  update('update'),
  delete('delete'),
  uploadFile('upload_file');

  const SyncOperation(this.wire);

  final String wire;

  static SyncOperation? fromWire(String value) {
    for (final op in SyncOperation.values) {
      if (op.wire == value) return op;
    }
    return null;
  }
}
