import 'package:colibri/features/sync/domain/progress_conflict_policy.dart';
import 'package:colibri/features/sync/domain/remote_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSignificantProgressConflict', () {
    test('cloud significantly ahead prompts', () {
      expect(
        isSignificantProgressConflict(localPercent: 42, remotePercent: 47.5),
        isTrue,
      );
    });

    test('minor drift resolves silently', () {
      expect(
        isSignificantProgressConflict(localPercent: 42, remotePercent: 45),
        isFalse,
      );
      expect(
        isSignificantProgressConflict(localPercent: 42, remotePercent: 47),
        isFalse, // exactly at threshold is not "significantly" ahead
      );
    });

    test('cloud behind local never prompts (no silent back-jumps)', () {
      expect(
        isSignificantProgressConflict(localPercent: 80, remotePercent: 10),
        isFalse,
      );
    });
  });

  group('RemoteProgress.fromRow', () {
    test('parses a PostgREST row and exposes text offsets', () {
      final progress = RemoteProgress.fromRow(<String, dynamic>{
        'locator_type': 'text_offset',
        'locator_value': '1500',
        'percent': 47.5,
        'page_number': 3,
        'updated_at': '2026-07-08T00:00:00Z',
      });
      expect(progress.percent, 47.5);
      expect(progress.textOffset, 1500);
      expect(progress.pageNumber, 3);
      expect(progress.updatedAt, isNotNull);
    });

    test('non-offset locators yield no text offset; nulls are safe', () {
      final pdf = RemoteProgress.fromRow(<String, dynamic>{
        'locator_type': 'pdf_page',
        'locator_value': '12',
        'percent': 30,
      });
      expect(pdf.textOffset, isNull);

      final sparse = RemoteProgress.fromRow(const <String, dynamic>{});
      expect(sparse.percent, 0);
      expect(sparse.textOffset, isNull);
      expect(sparse.updatedAt, isNull);
    });
  });
}
