import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import 'amplitude_analytics_repository.dart';

/// Boundary for product analytics (Phase 15).
///
/// The vendor sink (Amplitude — chosen over Firebase Analytics for its
/// key-only setup) plugs in here once an AMPLITUDE_API_KEY exists; until
/// then events flow to a debug sink in dev and nowhere in release.
///
/// Rules (from the project context): never log private book text, note
/// content, selected text, or raw file content.
abstract interface class AnalyticsRepository {
  Future<void> logEvent(String name, {Map<String, Object?> params});

  Future<void> logScreenView(String screenName);

  /// Allows analytics to be disabled (e.g. in dev builds).
  Future<void> setEnabled(bool enabled);
}

/// No-op sink: used when analytics is disabled by configuration.
class NoOpAnalyticsRepository implements AnalyticsRepository {
  const NoOpAnalyticsRepository();

  @override
  Future<void> logEvent(String name, {Map<String, Object?> params = const {}}) async {}

  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  Future<void> setEnabled(bool enabled) async {}
}

/// Development sink: prints events to the log so instrumentation can be
/// verified before a vendor key exists. Honors [setEnabled].
class DebugAnalyticsRepository implements AnalyticsRepository {
  bool _enabled = true;

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> params = const {},
  }) async {
    if (!_enabled) return;
    developer.log(params.isEmpty ? name : '$name $params', name: 'analytics');
  }

  @override
  Future<void> logScreenView(String screenName) =>
      logEvent('screen_view_$screenName');

  @override
  Future<void> setEnabled(bool enabled) async => _enabled = enabled;
}

/// App-wide analytics sink, chosen from config:
/// - analytics disabled           → no-op (dev default)
/// - enabled + AMPLITUDE_API_KEY   → Amplitude
/// - enabled, no key               → debug sink (events printed to the log)
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.analyticsEnabled) return const NoOpAnalyticsRepository();
  if (config.amplitudeApiKey.isNotEmpty) {
    return AmplitudeAnalyticsRepository(config.amplitudeApiKey);
  }
  return DebugAnalyticsRepository();
});