import 'package:flutter/material.dart';

/// A reusable, minimal placeholder scaffold used by foundation screens that do
/// not have real feature logic yet. Keeps each feature screen tiny while still
/// rendering a localized title and an optional subtitle/extra content.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.construction_outlined,
    this.child,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  /// Optional extra content rendered below the subtitle (e.g. dev navigation).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              if (child != null) ...<Widget>[
                const SizedBox(height: 24),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
