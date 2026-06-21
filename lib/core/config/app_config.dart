import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_environment.dart';

/// Strongly-typed view over the app's environment configuration.
///
/// Values are injected at compile time through `--dart-define` /
/// `--dart-define-from-file` and are never hardcoded into source. See
/// `.env.example` for the full list of keys and `README.md` for how to run
/// each flavor.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.sentryDsn,
    required this.analyticsEnabled,
  });

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String sentryDsn;
  final bool analyticsEnabled;

  /// Reads configuration from the compile-time environment.
  factory AppConfig.fromEnvironment() {
    return AppConfig(
      environment: AppEnvironment.fromName(
        const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
      ),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
      analyticsEnabled:
          const bool.fromEnvironment('ANALYTICS_ENABLED', defaultValue: false),
    );
  }

  /// Keys that are required for the app to function but are currently empty.
  List<String> get missingRequiredKeys {
    return <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ];
  }

  bool get isValid => missingRequiredKeys.isEmpty;

  /// Fails loudly (and early) when required values are missing so that
  /// misconfiguration is obvious during development instead of surfacing as a
  /// confusing runtime error deep inside a feature.
  void assertValid() {
    if (isValid) return;
    throw StateError(
      'Missing required environment values: ${missingRequiredKeys.join(', ')}.\n'
      'Provide them at run time, e.g. '
      '`flutter run --dart-define-from-file=.env.${environment.name}`.\n'
      'See .env.example for the full list of keys.',
    );
  }
}

/// Provides the loaded [AppConfig]. Overridden in `main()` so the rest of the
/// app can depend on configuration without reading compile-time defines
/// directly.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'appConfigProvider must be overridden in main() with AppConfig.fromEnvironment().',
  ),
);
