import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Boundary for product analytics. The concrete provider (Firebase Analytics
/// or Amplitude) is wired in Phase 15; for now a no-op implementation keeps
/// call sites safe and ensures no private book content is ever sent.
///
/// Rules (from the project context): never log private book text, note
/// content, selected text, or raw file content.
abstract interface class AnalyticsRepository {
  Future<void> logEvent(String name, {Map<String, Object?> params});

  Future<void> logScreenView(String screenName);

  /// Allows analytics to be disabled (e.g. in dev builds).
  Future<void> setEnabled(bool enabled);
}

/// Default no-op implementation used until Phase 15.
class NoOpAnalyticsRepository implements AnalyticsRepository {
  const NoOpAnalyticsRepository();

  @override
  Future<void> logEvent(String name, {Map<String, Object?> params = const {}}) async {}

  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  Future<void> setEnabled(bool enabled) async {}
}

/// App-wide analytics provider. Overridden with a real implementation in
/// Phase 15.
final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => const NoOpAnalyticsRepository(),
);
