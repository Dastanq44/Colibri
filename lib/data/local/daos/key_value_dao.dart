import 'package:drift/drift.dart';

import '../app_database.dart';
import '../db_time.dart';
import '../tables/system_tables.dart';

part 'key_value_dao.g.dart';

/// Small local key/value store. Backs the persistent device id service.
@DriftAccessor(tables: [LocalKeyValue])
class KeyValueDao extends DatabaseAccessor<AppDatabase>
    with _$KeyValueDaoMixin {
  KeyValueDao(super.db);

  Future<String?> getValue(String key) async {
    final row = await (select(localKeyValue)..where((kv) => kv.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) =>
      into(localKeyValue).insertOnConflictUpdate(
        LocalKeyValueCompanion(
          key: Value(key),
          value: Value(value),
          updatedAt: Value(dbNow()),
        ),
      );
}
