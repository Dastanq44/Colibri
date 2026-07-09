import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'data/remote/supabase_bootstrap.dart';
import 'data/remote/supabase_client_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The app is portrait-only; rotation is enabled only inside the reader
  // (ReaderScreen lifts this while it is open — landscape = fast mode).
  await SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[DeviceOrientation.portraitUp],
  );

  // Load and validate environment configuration. In dev, missing Supabase
  // keys are tolerated (the placeholder app still boots); in staging and
  // production a missing required value fails fast and clearly.
  final config = AppConfig.fromEnvironment();
  config.assertValid();

  // Initialize Supabase using the anon key only. Returns null in dev when no
  // keys are configured, so the placeholder app still boots without a backend.
  final SupabaseClient? supabaseClient = await initSupabase(config);

  final app = ProviderScope(
    overrides: <Override>[
      appConfigProvider.overrideWithValue(config),
      supabaseClientProvider.overrideWithValue(supabaseClient),
    ],
    child: const ColibriApp(),
  );

  // Crash reporting (TASK-1502): only when a DSN is configured — dev without
  // one runs plain. Reader errors are captured without book content; Sentry
  // includes app version and device context by default.
  if (config.sentryDsn.isEmpty) {
    runApp(app);
    return;
  }
  await SentryFlutter.init(
    (options) {
      options
        ..dsn = config.sentryDsn
        ..environment = config.environment.name
        ..tracesSampleRate = 0.2
        ..sendDefaultPii = false;
    },
    appRunner: () => runApp(SentryWidget(child: app)),
  );
}
