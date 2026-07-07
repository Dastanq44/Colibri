import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../data/onboarding_repository.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(appDatabaseProvider)),
);

/// Whether onboarding has been completed. Loaded once at startup (the app
/// shows a splash until this resolves, so the router redirect can rely on a
/// settled value); flips to true in place when the user finishes or skips.
final onboardingCompletedProvider =
    AsyncNotifierProvider<OnboardingCompletedNotifier, bool>(
  OnboardingCompletedNotifier.new,
);

class OnboardingCompletedNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(onboardingRepositoryProvider).isCompleted();

  /// Best-effort: a failed persist must never trap the user in onboarding
  /// (the flow proceeds for this session; onboarding may show again next
  /// launch). Mirrors the router's fail-open policy on the read side.
  Future<void> complete() async {
    try {
      await ref.read(onboardingRepositoryProvider).markCompleted();
    } catch (_) {
      // Swallow: continuing without the flag is strictly better than a
      // soft-lock on /onboarding.
    }
    state = const AsyncData(true);
  }
}
