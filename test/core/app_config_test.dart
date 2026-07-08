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
      amplitudeApiKey: "",
      );

      expect(config.isValid, isFalse);
      expect(
        config.missingRequiredKeys,
        containsAll(<String>['SUPABASE_URL', 'SUPABASE_ANON_KEY']),
      );
    });

    test('dev tolerates missing Supabase keys (does not throw)', () {
      const config = AppConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: '',
        supabaseAnonKey: '',
        sentryDsn: '',
        analyticsEnabled: false,
      amplitudeApiKey: "",
      );

      expect(config.isValid, isFalse);
      // Phase 0 placeholder app must still boot in dev without a backend.
      expect(config.assertValid, returnsNormally);
    });

    test('staging and production fail clearly on missing Supabase keys', () {
      const staging = AppConfig(
        environment: AppEnvironment.staging,
        supabaseUrl: '',
        supabaseAnonKey: '',
        sentryDsn: '',
        analyticsEnabled: false,
      amplitudeApiKey: "",
      );
      const production = AppConfig(
        environment: AppEnvironment.production,
        supabaseUrl: '',
        supabaseAnonKey: '',
        sentryDsn: '',
        analyticsEnabled: false,
      amplitudeApiKey: "",
      );

      expect(staging.assertValid, throwsStateError);
      expect(production.assertValid, throwsStateError);
    });

    test('is valid when required keys are present', () {
      const config = AppConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        sentryDsn: '',
        analyticsEnabled: false,
      amplitudeApiKey: "",
      );

      expect(config.isValid, isTrue);
      expect(config.missingRequiredKeys, isEmpty);
      // Should not throw.
      config.assertValid();
    });
  });
}
