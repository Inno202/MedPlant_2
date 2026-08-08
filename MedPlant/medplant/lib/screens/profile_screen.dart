// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/models/user_role.dart';
import 'package:medplant/providers/user_provider.dart';
import 'package:medplant/widgets/section_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final role = userProvider.role;

    final String roleLabel = role == UserRole.researcher
        ? "Researcher"
        : role == UserRole.communityUser
            ? "Community User"
            : "Guest";

    final String roleDescription = role == UserRole.researcher
        ? "Analytics dashboard · Species register · Degradation alerts · Report approval"
        : role == UserRole.communityUser
            ? "IK holder · Thaba-Nchu · Submit plant reports · View ML predictions"
            : "Not logged in";

    final IconData roleIcon = role == UserRole.researcher
        ? Icons.science
        : Icons.people;

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: "Profile"),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        role != null ? roleIcon : Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      role != null ? "Demo User" : "Guest",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      roleLabel,
                      style: GoogleFonts.montserrat(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Role description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        roleDescription,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Researcher quick-actions
                    if (role == UserRole.researcher) ...[
                      OutlinedButton.icon(
                        onPressed: () => context.go('/researcher/dashboard'),
                        icon: const Icon(Icons.dashboard,
                            color: AppColors.primary),
                        label: Text(
                          "Open Analytics Dashboard",
                          style: GoogleFonts.lato(color: AppColors.primary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.primary, width: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/approvereports'),
                        icon: const Icon(Icons.fact_check,
                            color: AppColors.primary),
                        label: Text(
                          "Review Flagged Reports",
                          style: GoogleFonts.lato(color: AppColors.primary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.primary, width: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Community user quick-action
                    if (role == UserRole.communityUser) ...[
                      OutlinedButton.icon(
                        onPressed: () => context.go('/addreport'),
                        icon: const Icon(Icons.add_a_photo,
                            color: AppColors.primary),
                        label: Text(
                          "Submit a Plant Report",
                          style: GoogleFonts.lato(color: AppColors.primary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.primary, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Login / Logout
                    ElevatedButton(
                      onPressed: () {
                        if (role != null) {
                          userProvider.setRole(null);
                          context.go('/login');
                        } else {
                          context.go('/login');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            role != null ? Colors.red : AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        role != null ? "Logout" : "Login",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}