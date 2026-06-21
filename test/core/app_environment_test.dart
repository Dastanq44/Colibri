import 'package:colibri/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment.fromName', () {
    test('parses known flavor names (case-insensitive)', () {
      expect(AppEnvironment.fromName('dev'), AppEnvironment.dev);
      expect(AppEnvironment.fromName('development'), AppEnvironment.dev);
      expect(AppEnvironment.fromName('STAGING'), AppEnvironment.staging);
      expect(AppEnvironment.fromName('stage'), AppEnvironment.staging);
      expect(AppEnvironment.fromName('prod'), AppEnvironment.production);
      expect(AppEnvironment.fromName('Production'), AppEnvironment.production);
    });

    test('falls back to dev for unknown values', () {
      expect(AppEnvironment.fromName(''), AppEnvironment.dev);
      expect(AppEnvironment.fromName('nonsense'), AppEnvironment.dev);
    });

    test('convenience getters are consistent', () {
      expect(AppEnvironment.production.isProduction, isTrue);
      expect(AppEnvironment.dev.isProduction, isFalse);
      expect(AppEnvironment.staging.isStaging, isTrue);
    });
  });
}
