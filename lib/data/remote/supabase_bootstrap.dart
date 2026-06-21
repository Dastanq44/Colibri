import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

/// Initializes Supabase from [AppConfig] and returns the client.
///
/// Returns `null` when the URL or anon key is missing (dev-safe: the
/// placeholder app still boots without a backend). Only the **anon key** is
/// used here — the service role key must never be referenced or bundled in the
/// client app.
Future<SupabaseClient?> initSupabase(AppConfig config) async {
  if (config.supabaseUrl.isEmpty || config.supabaseAnonKey.isEmpty) {
    return null;
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
    debug: !config.environment.isProduction,
  );

  return Supabase.instance.client;
}
