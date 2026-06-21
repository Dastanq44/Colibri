import '../../data/local/daos/key_value_dao.dart';
import '../utils/id_generator.dart';

/// Generates and persists a stable per-device id.
///
/// The id is created once and stored in the local key/value table, so it
/// survives app restarts. Reading progress and the sync engine use it to
/// attribute and reconcile changes across devices (Phase 12).
class DeviceIdService {
  DeviceIdService(this._keyValueDao);

  final KeyValueDao _keyValueDao;

  static const String _deviceIdKey = 'device_id';

  /// Returns the persisted device id, creating and storing one on first call.
  Future<String> getOrCreate() async {
    final existing = await _keyValueDao.getValue(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final id = IdGenerator.newId();
    await _keyValueDao.setValue(_deviceIdKey, id);
    return id;
  }

  /// Reads the device id without creating one (null if not yet generated).
  Future<String?> peek() => _keyValueDao.getValue(_deviceIdKey);
}
