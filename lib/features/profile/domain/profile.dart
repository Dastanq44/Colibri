/// Typed, UI-independent user profile (mirrors the `profiles` table).
class Profile {
  const Profile({
    required this.id,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.locale = 'ru-RU',
    this.timezone,
    this.goalDailyMinutes = 20,
    this.goalBooksYear = 12,
  });

  final String id;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final String locale;
  final String? timezone;
  final int goalDailyMinutes;
  final int goalBooksYear;

  /// Builds a [Profile] from a Supabase row map.
  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      displayName: map['display_name'] as String?,
      username: map['username'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      locale: (map['locale'] as String?) ?? 'ru-RU',
      timezone: map['timezone'] as String?,
      goalDailyMinutes: (map['goal_daily_minutes'] as num?)?.toInt() ?? 20,
      goalBooksYear: (map['goal_books_year'] as num?)?.toInt() ?? 12,
    );
  }

  Profile copyWith({
    String? displayName,
    String? username,
    String? avatarUrl,
    String? locale,
    String? timezone,
    int? goalDailyMinutes,
    int? goalBooksYear,
  }) {
    return Profile(
      id: id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      goalDailyMinutes: goalDailyMinutes ?? this.goalDailyMinutes,
      goalBooksYear: goalBooksYear ?? this.goalBooksYear,
    );
  }
}
