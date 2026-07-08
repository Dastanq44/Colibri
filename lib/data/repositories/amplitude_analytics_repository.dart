import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/events/base_event.dart';

import 'analytics_repository.dart';

/// Amplitude-backed [AnalyticsRepository]. Constructed only when an
/// AMPLITUDE_API_KEY is configured (see `analyticsRepositoryProvider`).
///
/// Privacy rule (project context): only the event names and small,
/// non-identifying params defined at call sites are sent here — never book
/// text, note content, selected passages, or file contents.
class AmplitudeAnalyticsRepository implements AnalyticsRepository {
  AmplitudeAnalyticsRepository(String apiKey)
      : _amplitude = Amplitude(Configuration(apiKey: apiKey));

  final Amplitude _amplitude;
  bool _enabled = true;

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> params = const {},
  }) async {
    if (!_enabled) return;
    await _amplitude.track(BaseEvent(
      name,
      eventProperties:
          params.isEmpty ? null : Map<String, dynamic>.from(params),
    ));
  }

  @override
  Future<void> logScreenView(String screenName) =>
      logEvent('screen_view_$screenName');

  @override
  Future<void> setEnabled(bool enabled) async {
    // Gate at the source: logEvent/logScreenView short-circuit on `_enabled`,
    // so no events are tracked when disabled. (Mutating configuration.optOut
    // here would not reach the already-initialized native SDK.)
    _enabled = enabled;
  }
}
