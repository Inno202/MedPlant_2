// lib/core/layout/app_shell.dart
// Main layout for the bottom-nav tabs (Home, Reports, Monitor, Dashboard,
// Profile). Navigation aligned with the two-role system.
//
// SAFE AREAS
//   The app runs edge-to-edge (see main.dart). The AppBar covers the
//   status bar, and the floating bottom nav adds the phone's bottom
//   system inset (gesture bar / 3-button bar) as padding, so the nav sits
//   just ABOVE the phone's own navigation — like WhatsApp — and page
//   content never slides underneath either bar.
//
// BACK BUTTON
//   • Drawer open           → closes the drawer
//   • On any tab but Home   → goes to Home
//   • On Home               → "Press back again to exit"
//   Previously every back press closed the app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/models/user_role.dart';
import 'package:medplant/providers/navigation_provider.dart';
import 'package:medplant/providers/user_provider.dart';

/// Confirms and performs logout. Shared by the drawer and profile screen.
Future<void> confirmAndLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will need to log in again to submit reports.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log out', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await context.read<UserProvider>().signOut();
  if (context.mounted) context.go('/home');
}

class AppShell extends StatefulWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPress;

  bool get _onHome => widget.location.startsWith('/home');

  void _handleBack() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return;
    }
    if (!_onHome) {
      context.go('/home');
      return;
    }
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Press back again to exit'),
        duration: Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final role = context.select<UserProvider, UserRole?>((u) => u.role);
    final tabs = NavigationProvider.tabsFor(role);
    final currentIndex = NavigationProvider.indexFor(tabs, widget.location);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          title: const Text(
            "MedPlant · Thaba-Nchu",
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            if (role == null)
              TextButton(
                onPressed: () => context.push('/login'),
                child: const Text('Login',
                    style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        drawer: _AppDrawer(
          location: widget.location,
          // Uses the shell's context: the drawer's own context is gone
          // once the drawer closes, which silently cancelled logout.
          onLogout: () => confirmAndLogout(context),
        ),
        body: widget.child,
        bottomNavigationBar: _FloatingNavBar(
          tabs: tabs,
          currentIndex: currentIndex,
          onTap: (i) => context.go(tabs[i].route),
        ),
      ),
    );
  }
}

// ── Floating bottom nav (original design) ───────────────────────────────
// Same look as before: white pill, icon only, and the label appears next
// to the icon of the selected tab. The only change is the bottom padding,
// which now includes the phone's own navigation bar so the pill sits
// above it instead of behind it.
class _FloatingNavBar extends StatelessWidget {
  final List<NavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final systemInset = MediaQuery.viewPaddingOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width > 700 ? (width - 640) / 2 : 16.0;

    return Padding(
      padding:
          EdgeInsets.fromLTRB(horizontal, 16, horizontal, 16 + systemInset),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(tabs.length, (i) {
            return _NavItem(
              tab: tabs[i],
              active: i == currentIndex,
              onTap: () => onTap(i),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavTab tab;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.tab, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(tab.activeIcon,
                color: active ? AppColors.primary : Colors.grey, size: 22),
            if (active) ...[
              const SizedBox(width: 6),
              Text(
                tab.label,
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
}

// ── Avatar with the user's initials ───────────────────────────────────────
class _AvatarBadge extends StatelessWidget {
  final double radius;
  const _AvatarBadge({this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final name = (user.username ?? '').trim();
    final initials = name.isEmpty
        ? null
        : name
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p[0].toUpperCase())
            .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: initials == null
          ? Icon(Icons.person, size: radius, color: AppColors.primary)
          : Text(initials,
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.75,
              )),
    );
  }
}

// ── Drawer ────────────────────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  final String location;
  final VoidCallback onLogout;
  const _AppDrawer({required this.location, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final role = user.role;
    final isResearcher = role == UserRole.researcher;
    final topInset = MediaQuery.paddingOf(context).top;

    final roleLabel = isResearcher
        ? "Researcher"
        : role == UserRole.communityUser
            ? "Community User"
            : "Guest";

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // ── Header (draws behind the status bar) ────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, topInset + 24, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AvatarBadge(radius: 30),
                const SizedBox(height: 12),
                Text(
                  role == null
                      ? 'Welcome to MedPlant'
                      : ((user.username?.isNotEmpty ?? false)
                          ? user.username!
                          : roleLabel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role == null
                      ? 'Log in to submit plant reports'
                      : '$roleLabel${(user.email?.isNotEmpty ?? false) ? ' · ${user.email}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _tab(context, "Home", Icons.home_rounded, '/home'),
                _tab(context, "Reports", Icons.description_rounded,
                    '/viewreports'),
                _tab(context, "Health Monitor", Icons.auto_awesome,
                    '/predictions'),
                _tab(context, "Profile", Icons.person_rounded, '/profile'),
                if (role == UserRole.communityUser)
                  _page(context, "Submit a Report", Icons.add_a_photo_rounded,
                      '/addreport'),
                if (isResearcher) ...[
                  const Divider(),
                  _sectionLabel("RESEARCHER"),
                  _tab(context, "Analytics Dashboard", Icons.dashboard_rounded,
                      '/researcher/dashboard'),
                  _page(context, "Review Reports", Icons.fact_check_rounded,
                      '/approvereports'),
                  _page(context, "Contact Messages", Icons.mail_rounded,
                      '/contactmessages'),
                ],
                const Divider(),
                _sectionLabel("MORE"),
                if (!isResearcher)
                  _page(context, "Contact Us", Icons.contact_mail_rounded,
                      '/contact'),
                _page(context, "About MedPlant", Icons.info_rounded, '/about'),
              ],
            ),
          ),

          const Divider(height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              leading: Icon(
                role == null ? Icons.login : Icons.logout,
                color: role == null ? AppColors.primary : Colors.red,
              ),
              title: Text(
                role == null ? "Login" : "Logout",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: role == null ? AppColors.primary : Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (role == null) {
                  context.push('/login');
                } else {
                  onLogout();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 1.2,
          ),
        ),
      );

  /// A bottom-nav tab: switches tab in place.
  Widget _tab(BuildContext context, String title, IconData icon, String route) {
    final active = location.startsWith(route);
    return _item(context, title, icon, active, () => context.go(route));
  }

  /// A secondary page: pushed so Back returns here.
  Widget _page(
      BuildContext context, String title, IconData icon, String route) {
    return _item(context, title, icon, false, () => context.push(route));
  }

  Widget _item(BuildContext context, String title, IconData icon, bool active,
      VoidCallback go) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon,
            color: active ? AppColors.primary : Colors.grey.shade600),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.primary : Colors.black87,
          ),
        ),
        tileColor:
            active ? AppColors.primary.withValues(alpha: 0.08) : null,
        onTap: () {
          Navigator.pop(context);
          go();
        },
      ),
    );
  }
}
