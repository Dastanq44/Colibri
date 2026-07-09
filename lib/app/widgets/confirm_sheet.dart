import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'glass.dart';

/// Modern iOS-style confirmation: a floating frosted-glass card that slides up
/// from the bottom, with a prominent (destructive) action and a quiet cancel —
/// replaces the dated full-width action sheet.
Future<bool> showModernConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final accent =
          destructive ? theme.colorScheme.error : theme.colorScheme.primary;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            blur: 24,
            tintAlpha: 0.82,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                // Prominent rounded action (filled, 50pt) — modern iOS.
                CupertinoButton(
                  color: accent,
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    confirmLabel,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    cancelLabel,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}
