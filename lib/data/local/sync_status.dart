import 'package:drift/drift.dart';

/// Sync state of a locally-stored row, shared across all `sync_status` columns.
///
/// The wire values are snake_case to match the cloud/sync convention; the
/// Dart enum names are camelCase. Stored via [SyncStatusConverter].
enum SyncStatus {
  localOnly('local_only'),
  pendingUpload('pending_upload'),
  pendingUpdate('pending_update'),
  synced('synced'),
  failed('failed'),
  deleted('deleted');

  const SyncStatus(this.wireValue);

  /// The string persisted in SQLite (and later sent to Supabase).
  final String wireValue;

  static SyncStatus fromWire(String value) => SyncStatus.values.firstWhere(
        (s) => s.wireValue == value,
        orElse: () => SyncStatus.localOnly,
      );
}

/// Maps [SyncStatus] <-> its snake_case wire value for Drift text columns.
class SyncStatusConverter extends TypeConverter<SyncStatus, String> {
  const SyncStatusConverter();

  @override
  SyncStatus fromSql(String fromDb) => SyncStatus.fromWire(fromDb);

  @override
  String toSql(SyncStatus value) => value.wireValue;
}
