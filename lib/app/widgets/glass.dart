import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Frosted-glass surface: blurs and lightly tints whatever is behind it.
/// Built on Flutter's own [BackdropFilter] (cheap, works everywhere) — used
/// for broad chrome (app-bar backdrops, cards, sheet panels). For the hero
/// floating chrome, see [GlassPanel] which uses the Liquid Glass shader.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.blur = 18,
    this.tintAlpha,
    this.border = true,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final double? tintAlpha;
  final bool border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = scheme.surface
        .withValues(alpha: tintAlpha ?? (isDark ? 0.4 : 0.6));
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: borderRadius,
            border: border
                ? Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.5),
                    width: 0.8,
                  )
                : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A Liquid Glass panel (Apple-style refraction/lensing via the
/// `liquid_glass_renderer` shader). Falls back to a [GlassSurface] on
/// platforms without Impeller. Use sparingly for hero chrome.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 28,
    this.blur = 6,
    this.thickness = 14,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LiquidGlass.withOwnLayer(
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: LiquidGlassSettings(
        blur: blur,
        thickness: thickness,
        glassColor: (isDark ? Colors.black : Colors.white)
            .withValues(alpha: isDark ? 0.18 : 0.12),
        lightIntensity: isDark ? 0.6 : 1.0,
        chromaticAberration: 0.03,
        refractiveIndex: 1.4,
        saturation: 1.1,
      ),
      child: child,
    );
  }
}
