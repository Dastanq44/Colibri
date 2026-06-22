import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/failures.dart';
import '../../core/result/result.dart';
import '../../features/profile/domain/profile.dart';
import 'profile_repository.dart';

/// Supabase-backed [ProfileRepository] over the `profiles` table.
///
/// Dev-safe: when the client is null (backend not configured) every method
/// returns a typed [BackendUnavailableFailure].
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient? _client;

  static const String _table = 'profiles';

  String? get _uid => _client?.auth.currentUser?.id;

  @override
  Future<Result<Profile>> getCurrentProfile() async {
    final client = _client;
    if (client == null) return const Err(BackendUnavailableFailure());
    final uid = _uid;
    if (uid == null) return const Err(UnauthorizedFailure('Not signed in.'));
    try {
      final row = await client
          .from(_table)
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return const Err(NotFoundFailure('Profile not found.'));
      return Ok(Profile.fromMap(row));
    } on PostgrestException catch (e) {
      return Err(_mapDbError(e));
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> ensureProfileForCurrentUser() async {
    final client = _client;
    if (client == null) return const Err(BackendUnavailableFailure());
    final uid = _uid;
    if (uid == null) return const Err(UnauthorizedFailure('Not signed in.'));
    try {
      // A DB trigger normally creates the row on sign-up; upsert is an
      // idempotent fallback that won't clobber an existing profile.
      await client
          .from(_table)
          .upsert(<String, dynamic>{'id': uid}, ignoreDuplicates: true);
      return const Ok(null);
    } on PostgrestException catch (e) {
      return Err(_mapDbError(e));
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> updateDisplayName(String displayName) =>
      _update(<String, dynamic>{'display_name': displayName});

  @override
  Future<Result<void>> updateLocale(String locale) =>
      _update(<String, dynamic>{'locale': locale});

  @override
  Future<Result<void>> updateGoals({
    int? goalDailyMinutes,
    int? goalBooksYear,
  }) {
    final patch = <String, dynamic>{
      if (goalDailyMinutes != null) 'goal_daily_minutes': goalDailyMinutes,
      if (goalBooksYear != null) 'goal_books_year': goalBooksYear,
    };
    if (patch.isEmpty) return Future.value(const Ok(null));
    return _update(patch);
  }

  Future<Result<void>> _update(Map<String, dynamic> patch) async {
    final client = _client;
    if (client == null) return const Err(BackendUnavailableFailure());
    final uid = _uid;
    if (uid == null) return const Err(UnauthorizedFailure('Not signed in.'));
    try {
      await client.from(_table).update(patch).eq('id', uid);
      return const Ok(null);
    } on PostgrestException catch (e) {
      return Err(_mapDbError(e));
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  Failure _mapDbError(PostgrestException e) {
    final code = int.tryParse(e.code ?? '');
    if (code == 401 || code == 403) return UnauthorizedFailure(e.message);
    return UnknownFailure(e.message);
  }
}
