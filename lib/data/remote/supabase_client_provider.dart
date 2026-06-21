import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The initialized Supabase client, or `null` when no backend is configured
/// (dev without keys). Overridden in `main()` after [initSupabase] runs.
///
/// Repositories depend on this provider; UI never talks to Supabase directly.
final supabaseClientProvider = Provider<SupabaseClient?>(
  (ref) => throw UnimplementedError(
    'supabaseClientProvider must be overridden in main() with the result of '
    'initSupabase(config).',
  ),
);

/// Whether a Supabase backend is configured and available this run.
final supabaseConfiguredProvider = Provider<bool>(
  (ref) => ref.watch(supabaseClientProvider) != null,
);
