import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'data/remote/supabase_bootstrap.dart';
import 'data/remote/supabase_client_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load and validate environment configuration. In dev, missing Supabase
  // keys are tolerated (the placeholder app still boots); in staging and
  // production a missing required value fails fast and clearly.
  final config = AppConfig.fromEnvironment();
  config.assertValid();

  // Initialize Supabase using the anon key only. Returns null in dev when no
  // keys are configured, so the placeholder app still boots without a backend.
  final SupabaseClient? supabaseClient = await initSupabase(config);

  // NOTE: Sentry initialization (Phase 15) hooks in here once that phase lands.

  runApp(
    ProviderScope(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(config),
        supabaseClientProvider.overrideWithValue(supabaseClient),
      ],
      child: const ColibriApp(),
    ),
  );
}
