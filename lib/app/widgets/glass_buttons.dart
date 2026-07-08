import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';

/// Round top-bar icon button rendered with Apple's **official Liquid Glass**:
/// on iOS this is a real native `UIButton` (glass configuration) embedded via
/// a platform view (`cupertino_native`'s `CNButton.icon`), so on iOS 26 it
/// gets the genuine system glass capsule. Other platforms fall back to a
/// plain Material [IconButton].
///
/// Used for navigation-bar actions everywhere except the reading mode.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.sfSymbol,
    required this.fallbackIcon,
    this.onPressed,
    this.semanticLabel,
    this.size = 40,
  });

  /// SF Symbol name used by the native button (e.g. `gearshape`, `plus`).
  final String sfSymbol;

  /// Material icon used on non-iOS platforms.
  final IconData fallbackIcon;

  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return Semantics(
        label: semanticLabel,
        button: true,
        child: SizedBox(
          width: size,
          height: size,
          child: CNButton.icon(
            icon: CNSymbol(sfSymbol, size: 17),
            size: size,
            onPressed: onPressed,
          ),
        ),
      );
    }
    return IconButton(
      tooltip: semanticLabel,
      icon: Icon(fallbackIcon),
      onPressed: onPressed,
    );
  }
}

/// Liquid Glass back chevron for pushed screens (matches [GlassIconButton]).
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GlassIconButton(
        sfSymbol: 'chevron.backward',
        fallbackIcon: Icons.arrow_back,
        semanticLabel: l10n.backButtonTooltip,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

/// Wraps [actions] for an AppBar so glass buttons keep a little breathing
/// room from the screen edge.
List<Widget> glassActions(List<Widget> actions) => <Widget>[
      ...actions.expand((w) => <Widget>[w, const SizedBox(width: 10)]),
    ];
