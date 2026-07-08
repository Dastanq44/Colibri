import 'package:flutter/material.dart';

/// A scaffold with an iOS-style large navigation title: the title sits large
/// and bold at the top and shrinks into a small toolbar title as the content
/// scrolls up. Content is supplied as slivers.
class LargeTitleScaffold extends StatelessWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions,
  });

  final String title;
  final List<Widget> slivers;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 116,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            actions: actions,
            flexibleSpace: FlexibleSpaceBar(
              // iOS large titles are left-aligned (not centered like the
              // collapsed toolbar title).
              centerTitle: false,
              titlePadding:
                  const EdgeInsetsDirectional.only(start: 16, bottom: 14, end: 16),
              // Collapsed ~18pt → expanded ~34pt (iOS large title).
              expandedTitleScale: 1.9,
              title: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          ...slivers,
        ],
      ),
    );
  }
}
