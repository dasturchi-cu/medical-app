import 'package:flutter/material.dart';

import '../core/localization/language_provider.dart';
import '../core/theme/app_palette.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bottomBar,
        border: Border(top: BorderSide(color: p.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          backgroundColor: p.bottomBar,
          indicatorColor: p.surfaceSecondary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: p.bottomBarText),
              selectedIcon: Icon(Icons.home, color: p.bottomBarActive),
              label: context.tr('nav_menu'),
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined, color: p.bottomBarText),
              selectedIcon: Icon(Icons.menu_book, color: p.bottomBarActive),
              label: context.tr('nav_my_courses'),
            ),
            NavigationDestination(
              icon: Icon(Icons.timer_outlined, color: p.bottomBarText),
              selectedIcon: Icon(Icons.timer, color: p.bottomBarActive),
              label: context.tr('nav_focus'),
            ),
            NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined, color: p.bottomBarText),
              selectedIcon: Icon(Icons.leaderboard, color: p.bottomBarActive),
              label: context.tr('nav_ranking'),
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: p.bottomBarText),
              selectedIcon: Icon(Icons.person, color: p.bottomBarActive),
              label: context.tr('nav_profile'),
            ),
          ],
        ),
      ),
    );
  }
}
