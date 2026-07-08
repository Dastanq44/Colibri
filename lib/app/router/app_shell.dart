import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/generated/app_localizations.dart';
import '../widgets/glass.dart';

/// Bottom-navigation shell hosting the four primary tabs, styled as a floating
/// **Liquid Glass** tab bar. Content flows behind the glass (extendBody), so
/// the bar refracts the scrolling content above it.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <_NavItem>[
      _NavItem(Icons.home_outlined, Icons.home, l10n.navHome),
      _NavItem(Icons.explore_outlined, Icons.explore, l10n.navCatalog),
      _NavItem(Icons.menu_book_outlined, Icons.menu_book, l10n.navLibrary),
      _NavItem(Icons.person_outline, Icons.person, l10n.navProfile),
    ];

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: GlassPanel(
            radius: 30,
            child: SizedBox(
              height: 62,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  for (var i = 0; i < items.length; i++)
                    _NavButton(
                      item: items[i],
                      selected: navigationShell.currentIndex == i,
                      onTap: () => _go(i),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color =
        selected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.5);
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(selected ? item.selectedIcon : item.icon,
                  color: color, size: 25),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
