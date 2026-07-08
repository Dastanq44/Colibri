import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/generated/app_localizations.dart';

/// Bottom-navigation shell hosting the four primary tabs.
///
/// On iOS this uses **`CNTabBar`** — a real native `UITabBar` embedded via a
/// platform view, so on iOS 26 it renders Apple's genuine Liquid Glass tab bar
/// (the actual system material / `.glassEffect()` equivalent), which Flutter's
/// own Skia/Impeller canvas cannot draw. Other platforms fall back to a
/// Material `NavigationBar`.
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
    final theme = Theme.of(context);
    final labels = <String>[
      l10n.navHome,
      l10n.navCatalog,
      l10n.navLibrary,
      l10n.navProfile,
    ];
    const symbols = <String>['house', 'safari', 'books.vertical', 'person'];

    final useNative = theme.platform == TargetPlatform.iOS;

    return Scaffold(
      extendBody: useNative,
      body: navigationShell,
      bottomNavigationBar: useNative
          ? CNTabBar(
              items: <CNTabBarItem>[
                for (var i = 0; i < labels.length; i++)
                  CNTabBarItem(label: labels[i], icon: CNSymbol(symbols[i])),
              ],
              currentIndex: navigationShell.currentIndex,
              onTap: _go,
              tint: theme.colorScheme.onSurface,
            )
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _go,
              destinations: <NavigationDestination>[
                NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: l10n.navHome),
                NavigationDestination(
                    icon: const Icon(Icons.explore_outlined),
                    selectedIcon: const Icon(Icons.explore),
                    label: l10n.navCatalog),
                NavigationDestination(
                    icon: const Icon(Icons.menu_book_outlined),
                    selectedIcon: const Icon(Icons.menu_book),
                    label: l10n.navLibrary),
                NavigationDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person),
                    label: l10n.navProfile),
              ],
            ),
    );
  }
}
