import 'package:colibri/core/config/app_config.dart';
import 'package:colibri/core/config/app_environment.dart';
import 'package:colibri/data/remote/supabase_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initSupabase returns null when keys are missing (dev-safe)', () async {
    const config = AppConfig(
      environment: AppEnvironment.dev,
      supabaseUrl: '',
      supabaseAnonKey: '',
      sentryDsn: '',
      analyticsEnabled: false,
    );

    // Must not touch Supabase.initialize when unconfigured.
    expect(await initSupabase(config), isNull);
  });
}
