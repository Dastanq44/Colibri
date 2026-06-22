import 'package:colibri/features/import/data/checksum_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const checksum = ChecksumService();

  test('identical content produces the same checksum', () {
    expect(
      checksum.sha256OfBytes(<int>[1, 2, 3, 4]),
      checksum.sha256OfBytes(<int>[1, 2, 3, 4]),
    );
  });

  test('different content produces different checksums', () {
    expect(
      checksum.sha256OfBytes(<int>[1, 2, 3, 4]),
      isNot(checksum.sha256OfBytes(<int>[1, 2, 3, 5])),
    );
  });
}
