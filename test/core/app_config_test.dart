import 'package:colibri/core/config/app_config.dart';
import 'package:colibri/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig validation', () {
    test('reports missing required keys', () {
      const config = AppConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: '',
        supabaseAnonKey: '',
        sentryDsn: '',
        analyticsEnabled: false,
      );

      expect(config.isValid, isFalse);
      expect(
        config.missingRequiredKeys,
        containsAll(<String>['SUPABASE_URL', 'SUPABASE_ANON_KEY']),
      );
      expect(config.assertValid, throwsStateError);
    });

    test('is valid when required keys are present', () {
      const config = AppConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        sentryDsn: '',
        analyticsEnabled: false,
      );

      expect(config.isValid, isTrue);
      expect(config.missingRequiredKeys, isEmpty);
      // Should not throw.
      config.assertValid();
    });
  });
}
