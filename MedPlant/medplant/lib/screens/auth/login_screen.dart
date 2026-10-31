// lib/screens/auth/login_screen.dart
// Firebase Authentication login.
// On success: fetches role from Firestore → navigates to /home

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '/constants/app_colors.dart';
import '/widgets/custom_text_field.dart';
import '/widgets/primary_button.dart';
import '/widgets/outlined_button.dart';
import '/providers/user_provider.dart';
import '/models/user_role.dart';
import '/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    FocusScope.of(context).unfocus();
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.login(
      email: emailController.text,
      password: passwordController.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      final userProvider = context.read<UserProvider>();

      userProvider.loginWithDetails(
        role: result['role'] as UserRole,
        uid: result['uid'],
        username: result['username'],
        email: result['email'],
      );
      // Return to the page that asked for login (e.g. Submit Report), or
      // Home if login was opened directly.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else {
      setState(() => _error = result['error']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
      backgroundColor: AppColors.accentBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primaryDark,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Container(
            width: size.width * 0.9,
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
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Column(
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
                        textAlign: TextAlign.center,
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
                      // Error message
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(12),
                            border: const Border(
                              left: BorderSide(
                                  color: Color(0xFFE74C3C), width: 4),
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                color: Color(0xFF9B2335), fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      CustomTextField(
                        label: 'Email',
                        hint: 'Enter your email',
                        icon: Icons.email,
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock,
                        obscureText: true,
                        controller: passwordController,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) {
                          if (!_loading) handleLogin();
                        },
                      ),
                      const SizedBox(height: 24),

                      _loading
                          ? const CircularProgressIndicator()
                          : PrimaryButton(
                              text: "Login",
                              icon: Icons.login,
                              onPressed: handleLogin,
                            ),

                      const SizedBox(height: 12),

                      OutlinedButtonWidget(
                        text: 'Create New Account',
                        icon: Icons.person_add,
                        onPressed: () => context.push('/register'),
                      ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: () => context.go('/home'),
                        child: const Text(
                          "Continue as guest",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
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
      ),
      ),
    );
  }
}
