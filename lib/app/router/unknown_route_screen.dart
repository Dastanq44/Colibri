import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/generated/app_localizations.dart';
import 'app_routes.dart';

/// Shown by GoRouter's `errorBuilder` when an unknown route is requested.
class UnknownRouteScreen extends StatelessWidget {
  const UnknownRouteScreen({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeNotFoundTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.broken_image_outlined, size: 48),
            const SizedBox(height: 16),
            Text(l10n.routeNotFoundBody(location)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(l10n.goToHome),
            ),
          ],
        ),
      ),
    );
  }
}
