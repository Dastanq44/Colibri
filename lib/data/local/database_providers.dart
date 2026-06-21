import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/device_id_service.dart';
import 'app_database.dart';

/// Single app-wide [AppDatabase] instance. Repositories depend on this (and the
/// DAOs it exposes); UI never reads DAOs directly.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Persistent device id service, backed by the local key/value table.
final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DeviceIdService(db.keyValueDao);
});
