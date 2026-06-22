import 'package:colibri/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile.fromMap', () {
    test('parses provided fields', () {
      final profile = Profile.fromMap(<String, dynamic>{
        'id': 'u1',
        'display_name': 'Alice',
        'username': 'alice',
        'locale': 'en-US',
        'goal_daily_minutes': 30,
        'goal_books_year': 24,
      });

      expect(profile.id, 'u1');
      expect(profile.displayName, 'Alice');
      expect(profile.username, 'alice');
      expect(profile.locale, 'en-US');
      expect(profile.goalDailyMinutes, 30);
      expect(profile.goalBooksYear, 24);
    });

    test('applies defaults for missing fields', () {
      final profile = Profile.fromMap(<String, dynamic>{'id': 'u2'});

      expect(profile.displayName, isNull);
      expect(profile.locale, 'ru-RU');
      expect(profile.goalDailyMinutes, 20);
      expect(profile.goalBooksYear, 12);
    });
  });
}
