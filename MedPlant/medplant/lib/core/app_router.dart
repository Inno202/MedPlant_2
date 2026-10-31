// lib/core/app_router.dart
// Routes aligned with two-role system:
//   communityUser → home, viewreports, predictions, profile
//   researcher    → home, viewreports (+ approve), predictions,
//                   researcher/dashboard, profile
//
// NAVIGATION RULES (used consistently across the app):
//   • Bottom-nav tabs (inside the ShellRoute) are switched with context.go.
//   • Secondary pages (outside the shell) are opened with context.push so
//     the phone's back button / the AppBar back arrow returns to the
//     page you came from instead of closing the app.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/models/user_role.dart';
import 'package:medplant/screens/about_us.dart';
import 'package:medplant/screens/admin_contact_message_screen.dart';
import 'package:medplant/screens/contact_us.dart';
import 'package:medplant/screens/profile_screen.dart';
import 'package:medplant/core/layout/app_shell.dart';
import 'package:medplant/models/plant_model.dart';
import 'package:medplant/screens/auth/login_screen.dart';
import 'package:medplant/screens/auth/register_screen.dart';
import 'package:medplant/screens/user/user_home_screen.dart';
import 'package:medplant/screens/user/view_reports_screen.dart';
import 'package:medplant/screens/user/predictions_screen.dart';
import 'package:medplant/screens/user/plant_detail_screen.dart';
import 'package:medplant/screens/user/add_report_screen.dart';
import 'package:medplant/screens/field_manager/approve_reports_screen.dart';
import 'package:medplant/widgets/auth_guard.dart';
import 'package:medplant/widgets/secondary_scaffold.dart';

// Researcher dashboard replaces the old admin dashboard
import 'package:medplant/screens/admin/admin_dashboard.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/home',
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      // ── Auth (no shell) ──────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── Main app (with nav bar + drawer) ────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          // Shared routes (both roles)
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: UserHomeScreen()),
          ),
          GoRoute(
            path: '/viewreports',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ViewReportsScreen()),
          ),
          GoRoute(
            path: '/predictions',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PredictionsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),

          // Researcher-only route
          GoRoute(
            path: '/researcher/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AuthGuard(
                allowedRoles: [UserRole.researcher],
                message: "Please log in as a researcher to view the dashboard.",
                restrictedMessage:
                    "The analytics dashboard is only available to researchers.",
                child: AdminDashboardScreen(),
              ),
            ),
          ),
        ],
      ),

      // ── Secondary screens (outside shell, opened with push) ─────────────
      GoRoute(
        path: '/plantdetail',
        builder: (context, state) {
          final plant = state.extra;
          // `extra` is lost on a web refresh / deep link — show a friendly
          // page instead of crashing with a cast error.
          if (plant is! PlantModel) return const _NotFoundScreen();
          return PlantDetailScreen(plant: plant);
        },
      ),
      GoRoute(
        path: '/addreport',
        builder: (context, state) => const AddReportScreen(),
      ),
      // Researcher quality-gate: approve/reject flagged submissions
      GoRoute(
        path: '/approvereports',
        builder: (context, state) => const _GuardedSecondary(
          title: 'Report Review',
          child: ApproveReportsScreen(),
        ),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/contactmessages',
        builder: (context, state) => const _GuardedSecondary(
          title: 'Contact Messages',
          child: AdminContactMessagesScreen(),
        ),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => const ContactScreen(),
      ),
    ],
  );
}

/// Researcher-only secondary page. If the visitor is not a researcher the
/// guard message is shown inside the normal secondary layout (with a back
/// button) rather than a bare full-screen page.
class _GuardedSecondary extends StatelessWidget {
  final String title;
  final Widget child;
  const _GuardedSecondary({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      allowedRoles: const [UserRole.researcher],
      message: "Please log in as a researcher to open this page.",
      restrictedMessage: "This page is only available to researchers.",
      wrapper: (guard) => SecondaryScaffold(title: title, body: guard),
      child: child,
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return SecondaryScaffold(
      title: 'Page not found',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.travel_explore,
                  size: 56, color: AppColors.primarySoft),
              const SizedBox(height: 12),
              const Text(
                "We couldn't open that page.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_rounded, color: Colors.white),
                label: const Text('Back to Home',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
