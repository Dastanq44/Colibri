import 'package:colibri/core/errors/failures.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/repositories/supabase_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseProfileRepository with no backend configured', () {
    final repo = SupabaseProfileRepository(null);

    test('getCurrentProfile returns BackendUnavailableFailure', () async {
      final result = await repo.getCurrentProfile();
      expect(result.isErr, isTrue);
      expect((result as Err).failure, isA<BackendUnavailableFailure>());
    });

    test('mutations return BackendUnavailableFailure', () async {
      final results = <Result<void>>[
        await repo.ensureProfileForCurrentUser(),
        await repo.updateDisplayName('Alice'),
        await repo.updateLocale('en-US'),
        await repo.updateGoals(goalDailyMinutes: 30, goalBooksYear: 24),
      ];
      for (final result in results) {
        expect((result as Err<void>).failure, isA<BackendUnavailableFailure>());
      }
    });
  });
}
