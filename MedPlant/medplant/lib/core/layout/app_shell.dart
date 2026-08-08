// lib/core/layout/app_shell.dart
// Navigation aligned with two-role system (communityUser / researcher)
//
// SAFE-AREA NOTES:
// - The custom bottom nav bar is wrapped in SafeArea(top: false) so it sits
//   above the phone's gesture bar / on-screen nav buttons instead of under
//   them.
// - The Scaffold body is wrapped in SafeArea(top: false) too, so any screen
//   rendered inside this shell automatically gets safe bottom insets
//   without every individual screen having to remember to do it itself.
//   (top: false because the AppBar already handles the status bar area.)
// - The Drawer's own content is wrapped in SafeArea so the Login/Logout
//   button at the bottom isn't obscured by the system nav bar either.

import 'package:flutter/material.dart';
import 'package:medplant/providers/user_provider.dart';
import 'package:medplant/widgets/drawer_nav_item.dart';
import 'package:provider/provider.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/providers/navigation_provider.dart';
import 'package:medplant/models/user_role.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: const Text(
          "MedPlant · Thaba-Nchu",
          style: TextStyle(color: Colors.white),
        ),
      ),
      drawer: _buildDrawer(context, navProvider),
      // top: false — the AppBar already accounts for the status bar, we
      // just need to make sure content doesn't sit flush against the
      // bottom system nav / gesture bar.
      body: SafeArea(
        top: false,
        bottom: false, // bottomNavigationBar below already reserves this
        child: child,
      ),
      bottomNavigationBar: _buildBottomNav(context, navProvider),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav(
      BuildContext context, NavigationProvider navProvider) {
    final labels = navProvider.routes.map(_labelForRoute).toList();
    final icons = navProvider.routes.map(_iconForRoute).toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navProvider.routes.length, (index) {
              return _navItem(
                context,
                icons[index],
                labels[index],
                index,
                navProvider,
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int index,
      NavigationProvider navProvider) {
    final isActive = navProvider.currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (index < 0 || index >= navProvider.routes.length) return;
        final route = navProvider.routes[index];
        navProvider.setIndex(index);
        context.go(route);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isActive ? AppColors.primary : Colors.grey, size: 22),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer(
      BuildContext context, NavigationProvider navProvider) {
    final userProvider = Provider.of<UserProvider>(context);
    final role = userProvider.role;
    final isResearcher = role == UserRole.researcher;

    final String roleLabel = isResearcher
        ? "Researcher"
        : role == UserRole.communityUser
            ? "Community User"
            : "Guest";

    final String roleSubtitle = isResearcher
        ? "Analytics · Species Register · Alerts"
        : role == UserRole.communityUser
            ? "IK Holder · Thaba-Nchu"
            : "Not logged in";

    return Drawer(
      child: SafeArea(
        // top: true (default) so the drawer header itself doesn't sit
        // under the status bar; bottom stays true (default) so the
        // Login/Logout tile clears the system nav bar / gesture area.
        child: Column(
          children: [
            // ── User header ─────────────────────────────────────────────────
            if (role != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 30, bottom: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: Icon(
                        isResearcher ? Icons.science : Icons.people,
                        size: 35,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      roleLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roleSubtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            // ── Scrollable middle section ──────────────────────────────────
            // Wrapped in Expanded + ListView so a long list of nav items on
            // a short/landscape screen scrolls instead of overflowing —
            // same reasoning as the earlier profile screen overflow fix.
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── Shared nav items ─────────────────────────────────────────────
                  _drawerItem(context, "Home", Icons.home, '/home'),
                  _drawerItem(context, "Reports", Icons.description, '/viewreports'),
                  _drawerItem(context, "Predictions", Icons.auto_awesome, '/predictions'),
                  _drawerItem(context, "Profile", Icons.person, '/profile'),

                  // ── Researcher-only nav items ────────────────────────────────────
                  if (isResearcher) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "RESEARCHER",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500],
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    _drawerItem(
                      context,
                      "Analytics Dashboard",
                      Icons.dashboard,
                      '/researcher/dashboard',
                    ),
                    _drawerItem(
                      context,
                      "Approve Reports",
                      Icons.fact_check,
                      '/approvereports',
                    ),
                    _drawerItem(
                      context,
                      "Contact Messages",
                      Icons.message,
                      '/contactmessages',
                    ),
                  ],

                  // ── Community-only nav items ─────────────────────────────────────
                  if (role == UserRole.communityUser) ...[
                    const DrawerNavItem(
                      title: "Contact Us",
                      icon: Icons.contact_mail,
                      route: "/contact",
                    ),
                  ],

                  const DrawerNavItem(
                    title: "About MedPlant",
                    icon: Icons.info,
                    route: "/about",
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Login / Logout ────────────────────────────────────────────────
            ListTile(
              leading: Icon(
                role == null ? Icons.login : Icons.logout,
                color: role == null ? AppColors.primary : Colors.red,
              ),
              title: Text(
                role == null ? "Login" : "Logout",
                style: TextStyle(
                  color: role == null ? AppColors.primary : Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (role == null) {
                  context.go('/login');
                } else {
                  userProvider.setRole(null);
                  context.go('/login');
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
      BuildContext context, String title, IconData icon, String route) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final isActive = currentRoute == route;

    return ListTile(
      leading: Icon(icon, color: isActive ? AppColors.primary : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? AppColors.primary : Colors.black87,
        ),
      ),
      tileColor: isActive
          ? AppColors.primary.withOpacity(0.08)
          : Colors.transparent,
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }

  // ── Route helpers ─────────────────────────────────────────────────────────
  String _labelForRoute(String route) {
    if (route.contains('dashboard')) return "Dashboard";
    if (route.contains('approvereports')) return "Approve";
    if (route.contains('viewreports')) return "Reports";
    if (route.contains('predictions')) return "Monitor";
    if (route.contains('home')) return "Home";
    return "Profile";
  }

  IconData _iconForRoute(String route) {
    if (route.contains('dashboard')) return Icons.dashboard;
    if (route.contains('approvereports')) return Icons.fact_check;
    if (route.contains('viewreports')) return Icons.description;
    if (route.contains('predictions')) return Icons.auto_awesome;
    if (route.contains('home')) return Icons.home;
    return Icons.person;
  }
}