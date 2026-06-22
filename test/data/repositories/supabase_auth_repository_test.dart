import 'package:colibri/core/errors/failures.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/repositories/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseAuthRepository with no backend configured', () {
    final repo = SupabaseAuthRepository(null);

    test('currentUser and currentUserId are null', () {
      expect(repo.currentUser, isNull);
      expect(repo.currentUserId, isNull);
    });

    test('authStateChanges emits null', () async {
      expect(await repo.authStateChanges().first, isNull);
    });

    test('auth actions return BackendUnavailableFailure', () async {
      final results = <Result<void>>[
        await repo.signIn(email: 'a@b.com', password: 'secret1'),
        await repo.signUp(email: 'a@b.com', password: 'secret1'),
        await repo.signOut(),
        await repo.sendPasswordReset('a@b.com'),
        await repo.deleteAccount(),
      ];
      for (final result in results) {
        expect(result, isA<Err<void>>());
        expect((result as Err<void>).failure, isA<BackendUnavailableFailure>());
      }
    });
  });
}
