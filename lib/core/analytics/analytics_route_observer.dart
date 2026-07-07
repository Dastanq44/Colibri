import 'package:flutter/widgets.dart';

import '../../data/repositories/analytics_repository.dart';

/// Logs `screen_view_<route name>` on navigation (plan §14.1). A navigator
/// accepts an observer instance only once, so create one per navigator
/// (root + each tab branch).
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);

  final AnalyticsRepository _analytics;

  void _log(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) return;
    _analytics.logScreenView(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log(previousRoute);
}
