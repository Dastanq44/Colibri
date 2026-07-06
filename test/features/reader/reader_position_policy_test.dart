import 'package:colibri/features/reader/application/reader_position_policy.dart';
import 'package:colibri/features/reader/domain/reader_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('saveActiveModePosition', () {
    test('portrait active issues exactly one save — the reader\'s', () {
      var normal = 0;
      var fast = 0;
      saveActiveModePosition(
        mode: ReaderMode.normal,
        saveNormal: () => normal++,
        saveFast: () => fast++,
      );
      expect(normal, 1);
      expect(fast, 0, reason: 'engine must never persist when inactive');
    });

    test('fast mode active issues exactly one save — the engine\'s', () {
      var normal = 0;
      var fast = 0;
      saveActiveModePosition(
        mode: ReaderMode.fast,
        saveNormal: () => normal++,
        saveFast: () => fast++,
      );
      expect(normal, 0, reason: 'portrait position is stale in fast mode');
      expect(fast, 1);
    });
  });

  group('shouldSeekFastEngine', () {
    test('keeps the engine position when inside [pageStart, pageEnd)', () {
      expect(
        shouldSeekFastEngine(engineOffset: 3000, pageStart: 3000, pageEnd: 4500),
        isFalse,
      );
      expect(
        shouldSeekFastEngine(engineOffset: 4499, pageStart: 3000, pageEnd: 4500),
        isFalse,
      );
    });

    test('seeks when outside the current page', () {
      expect(
        shouldSeekFastEngine(engineOffset: 2999, pageStart: 3000, pageEnd: 4500),
        isTrue,
      );
      expect(
        shouldSeekFastEngine(engineOffset: 4500, pageStart: 3000, pageEnd: 4500),
        isTrue,
        reason: 'endOffset is exclusive',
      );
    });

    test('seeks when the engine has no position yet', () {
      expect(
        shouldSeekFastEngine(engineOffset: null, pageStart: 0, pageEnd: 10),
        isTrue,
      );
    });
  });
}
