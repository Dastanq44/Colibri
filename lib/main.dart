import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load and validate environment configuration. In dev, missing Supabase
  // keys are tolerated (the placeholder app still boots); in staging and
  // production a missing required value fails fast and clearly.
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
