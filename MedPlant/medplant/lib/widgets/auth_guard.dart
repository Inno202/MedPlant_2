import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/models/user_role.dart';
import 'package:medplant/providers/user_provider.dart';

/// Wrap any screen that should only be visible to logged-in users, and
/// optionally to a restricted set of roles.
///
/// - No session               → login prompt
/// - Session but wrong role   → "not permitted" message (only shown when
///                               [allowedRoles] is provided)
class AuthGuard extends StatelessWidget {
  final Widget child;
  final String message;
  final List<UserRole>? allowedRoles;
  final String restrictedMessage;

  const AuthGuard({
    super.key,
    required this.child,
    this.message = "Please log in to view this page.",
    this.allowedRoles,
    this.restrictedMessage = "You don't have access to this page.",
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    if (!userProvider.isLoggedIn) {
      return _guardScaffold(
        context,
        icon: Icons.lock_outline,
        text: message,
        showLoginButton: true,
      );
    }

    if (allowedRoles != null &&
        !allowedRoles!.contains(userProvider.role)) {
      return _guardScaffold(
        context,
        icon: Icons.block,
        text: restrictedMessage,
        showLoginButton: false,
      );
    }

    return child;
  }

  Widget _guardScaffold(
    BuildContext context, {
    required IconData icon,
    required String text,
    required bool showLoginButton,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (showLoginButton)
                ElevatedButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login, color: Colors.white),
                  label: const Text("Login",
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home, color: AppColors.primaryDark),
                  label: const Text("Back to Home",
                      style: TextStyle(color: AppColors.primaryDark)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.primaryDark, width: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
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