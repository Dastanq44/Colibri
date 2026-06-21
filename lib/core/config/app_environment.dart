/// Build flavors supported by the app.
///
/// The active environment is selected at build/run time via the `APP_ENV`
/// compile-time define, e.g.:
///
/// ```
/// flutter run --dart-define-from-file=.env.dev
/// ```
enum AppEnvironment {
  dev,
  staging,
  production;

  /// Parses a flavor name coming from `APP_ENV`. Unknown values fall back to
  /// [AppEnvironment.dev] so local development never hard-fails on a typo.
  static AppEnvironment fromName(String name) {
    switch (name.trim().toLowerCase()) {
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      case 'prod':
      case 'production':
        return AppEnvironment.production;
      case 'dev':
      case 'development':
      default:
        return AppEnvironment.dev;
    }
  }

  bool get isDev => this == AppEnvironment.dev;
  bool get isStaging => this == AppEnvironment.staging;
  bool get isProduction => this == AppEnvironment.production;

  String get displayName => name;
}
