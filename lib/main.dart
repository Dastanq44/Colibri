import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load and validate environment configuration. Fails fast and clearly if a
  // required value (e.g. SUPABASE_URL) is missing.
  final config = AppConfig.fromEnvironment();
  config.assertValid();

  // NOTE: Supabase initialization (Phase 1) and Sentry initialization
  // (Phase 15) hook in here once those phases land.

  runApp(
    ProviderScope(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(config),
      ],
      child: const ColibriApp(),
    ),
  );
}
