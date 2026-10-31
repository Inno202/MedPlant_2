// lib/providers/navigation_provider.dart
// Two-role navigation aligned with research proposal actors:
//   communityUser / guest → Home, Reports, Monitor, Profile
//   researcher            → Home, Reports, Monitor, Dashboard, Profile
//
// The bottom-nav tabs are derived from the user's role, and the active
// tab is derived from the current URL. Nothing here is mutated during a
// widget build (the old version called notifyListeners() from inside
// build methods, which throws "setState() called during build" and kept
// resetting the selected tab to Home).

import 'package:flutter/material.dart';
import '../models/user_role.dart';

class NavTab {
  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavTab(this.route, this.label, this.icon, this.activeIcon);
}

class NavigationProvider extends ChangeNotifier {
  static const _home =
      NavTab('/home', 'Home', Icons.home_outlined, Icons.home_rounded);
  static const _reports = NavTab('/viewreports', 'Reports',
      Icons.description_outlined, Icons.description_rounded);
  static const _monitor = NavTab('/predictions', 'Monitor',
      Icons.auto_awesome_outlined, Icons.auto_awesome);
  static const _dashboard = NavTab('/researcher/dashboard', 'Dashboard',
      Icons.dashboard_outlined, Icons.dashboard_rounded);
  static const _profile =
      NavTab('/profile', 'Profile', Icons.person_outline, Icons.person_rounded);

  /// Tabs shown in the bottom navigation bar for [role].
  static List<NavTab> tabsFor(UserRole? role) => role == UserRole.researcher
      ? const [_home, _reports, _monitor, _dashboard, _profile]
      : const [_home, _reports, _monitor, _profile];

  /// Index of the tab matching [location], or -1 if none matches.
  static int indexFor(List<NavTab> tabs, String location) =>
      tabs.indexWhere((t) => location.startsWith(t.route));

  // ── Kept for backward compatibility with existing callers ─────────────
  List<String> _routes = tabsFor(null).map((t) => t.route).toList();
  List<String> get routes => _routes;

  /// Called by the ProxyProvider in main.dart whenever the role changes.
  /// It deliberately does NOT call notifyListeners(): it runs while the
  /// provider tree is building, and the bottom nav reads its tabs from
  /// [tabsFor] directly.
  void configureRoutes(UserRole? role) {
    _routes = tabsFor(role).map((t) => t.route).toList();
  }
}
