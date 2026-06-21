import 'package:colibri/core/platform/device_id_service.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('generates an id and returns the same one on subsequent calls', () async {
    final service = DeviceIdService(db.keyValueDao);

    expect(await service.peek(), isNull);

    final first = await service.getOrCreate();
    expect(first, isNotEmpty);

    final second = await service.getOrCreate();
    expect(second, first, reason: 'device id must be stable');
    expect(await service.peek(), first);
  });

  test('different stores produce different ids', () async {
    final other = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(other.close);

    final id1 = await DeviceIdService(db.keyValueDao).getOrCreate();
    final id2 = await DeviceIdService(other.keyValueDao).getOrCreate();

    expect(id1, isNot(equals(id2)));
  });
}
