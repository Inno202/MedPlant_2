// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/providers/navigation_provider.dart';
import 'package:provider/provider.dart';

import '/constants/app_colors.dart';
import '/widgets/custom_text_field.dart';
import '/widgets/primary_button.dart';
import '/widgets/outlined_button.dart';
import '/providers/user_provider.dart';
import '/models/user_role.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void handleLogin(BuildContext context) {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    final userProvider = context.read<UserProvider>();
    final navProvider = context.read<NavigationProvider>();

    if (username == 'community' && password == '1234') {
      userProvider.login(UserRole.communityUser);
    } else if (username == 'researcher' && password == '1234') {
      userProvider.login(UserRole.researcher);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid username or password')),
      );
      return;
    }

    navProvider.configureRoutes(userProvider.role);

    debugPrint("ROLE: ${userProvider.role}");
    debugPrint("ROUTES: ${navProvider.routes}");

    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.accentBg,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.white,
                        child: const FaIcon(
                          FontAwesomeIcons.seedling,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'MedPlant · Thaba-Nchu',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '... sign in to continue ...',
                        style: GoogleFonts.dancingScript(
                          color: AppColors.primarySoft,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'Username',
                        hint: 'Enter your username',
                        icon: Icons.person,
                        controller: usernameController,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock,
                        obscureText: true,
                        controller: passwordController,
                      ),
                      const SizedBox(height: 24),

                      PrimaryButton(
                        text: "Login",
                        icon: Icons.login,
                        onPressed: () => handleLogin(context),
                      ),

                      const SizedBox(height: 12),

                      OutlinedButtonWidget(
                        text: 'Create New Account',
                        icon: Icons.person_add,
                        onPressed: () => context.push('/register'),
                      ),

                      const SizedBox(height: 8),

                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Forgot Password functionality')),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                              color: AppColors.primaryDark, fontSize: 14),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Demo credentials — research roles
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accentBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Demo Accounts",
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _demoRow(
                              Icons.people,
                              "Community User",
                              "community / 1234",
                              "Traditional healer or IK holder in Thaba-Nchu",
                            ),
                            const SizedBox(height: 8),
                            _demoRow(
                              Icons.science,
                              "Researcher",
                              "researcher / 1234",
                              "Analytics dashboard, species register, degradation alerts",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoRow(
      IconData icon, String role, String credentials, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$role — $credentials",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
