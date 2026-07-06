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

  /// Parses a flavor name coming from `APP_ENV`.
  ///
  /// A missing/empty value falls back to [AppEnvironment.dev] so local
  /// development boots without any defines. Any other unrecognized value
  /// (e.g. a typo like `produciton`) throws so a misconfigured build fails
  /// fast at startup instead of silently running as dev.
  static AppEnvironment fromName(String name) {
    switch (name.trim().toLowerCase()) {
      case '':
      case 'dev':
      case 'development':
        return AppEnvironment.dev;
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      case 'prod':
      case 'production':
        return AppEnvironment.production;
      default:
        throw ArgumentError.value(
          name,
          'APP_ENV',
          'Unknown environment name. Allowed values: dev, development, '
              'staging, stage, prod, production (empty defaults to dev)',
        );
    }
  }

  bool get isDev => this == AppEnvironment.dev;
  bool get isStaging => this == AppEnvironment.staging;
  bool get isProduction => this == AppEnvironment.production;

  String get displayName => name;
}
