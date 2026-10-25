import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import 'screens/collect_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_screen.dart';
import 'screens/more_screen.dart';

/// App shell: bottom navigation with ≤ 4 labeled destinations
/// (Home · Live · Record · More) over an IndexedStack, so switching tabs
/// keeps each screen's state. Routes (pushNamed) still work for deep
/// links and tests.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = [
    (label: AppStrings.homeTab, icon: Icons.chat_bubble_outline),
    (label: AppStrings.liveTitle, icon: Icons.back_hand_outlined),
    (label: AppStrings.recordModeTitle, icon: Icons.fiber_manual_record_outlined),
    (label: AppStrings.moreTab, icon: Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        // TickerMode mutes off-tab tickers (Live's frame clock, hand
        // low-pass) so hidden tabs never animate — tests can settle and
        // no frame is wasted off-screen.
        children: [
          for (final (i, screen) in [
            (0, const HomeScreen()),
            (1, const LiveScreen()),
            (2, const CollectScreen()),
            (3, const MoreScreen()),
          ])
            TickerMode(enabled: _index == i, child: screen),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
