import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/widgets/badge_chip.dart';
import '/constants/app_colors.dart';
import '/widgets/custom_text_field.dart';
import '/widgets/primary_button.dart';
import '/widgets/outlined_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final contactController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final countryController = TextEditingController();
  final provinceController = TextEditingController();

  String? passwordError;

  bool validatePasswords() {
    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        passwordError = "Passwords do not match";
      });
      return false;
    } else {
      setState(() {
        passwordError = null;
      });
      return true;
    }
  }

  void handleRegister() {
    if (!_formKey.currentState!.validate()) return;
    if (!validatePasswords()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Registration successful")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accentBg, AppColors.accentBgDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                width: size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 500),
                margin: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.borderSoft),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),

                // ===== FULL CARD CONTENT =====
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ===== HEADER =====
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 32, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.accentBg,
                            AppColors.accentBgDark
                          ],
                        ),
                        // border: Border(
                        //   bottom: BorderSide(
                        //     color: AppColors.borderSoft,
                        //     width: 2,
                        //   ),
                        // ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const FaIcon(
                              FontAwesomeIcons.leaf,
                              size: 32,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 14),

                          Text(
                            "Create account",
                            style: GoogleFonts.montserrat(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 6),

                          Text(
                            "... become part of the community ...",
                            style: GoogleFonts.dancingScript(
                              color: AppColors.primary,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ===== BODY =====
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            CustomTextField(
                              label: "Username",
                              hint: "Enter username",
                              icon: FontAwesomeIcons.user,
                              controller: usernameController,
                              validator: (v) =>
                                  v!.isEmpty ? "Required" : null,
                            ),
                            const SizedBox(height: 14),

                            CustomTextField(
                              label: "Email",
                              hint: "Enter email",
                              icon: FontAwesomeIcons.envelope,
                              controller: emailController,
                              validator: (v) =>
                                  v!.isEmpty ? "Required" : null,
                            ),
                            const SizedBox(height: 14),

                            CustomTextField(
                              label: "Contact",
                              hint: "Enter contact number",
                              icon: FontAwesomeIcons.phone,
                              controller: contactController,
                              validator: (v) =>
                                  v!.isEmpty ? "Required" : null,
                            ),
                            const SizedBox(height: 14),

                            CustomTextField(
                              label: "Password",
                              hint: "Enter password",
                              icon: FontAwesomeIcons.lock,
                              controller: passwordController,
                              obscureText: true,
                              validator: (v) =>
                                  v!.isEmpty ? "Required" : null,
                            ),
                            const SizedBox(height: 14),

                            CustomTextField(
                              label: "Confirm Password",
                              hint: "Re-type password",
                              icon: FontAwesomeIcons.lock,
                              controller: confirmPasswordController,
                              obscureText: true,
                              validator: (v) =>
                                  v!.isEmpty ? "Required" : null,
                            ),

                            if (passwordError != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const FaIcon(
                                    FontAwesomeIcons.circleExclamation,
                                    size: 14,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    passwordError!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 14),

                            CustomTextField(
                              label: "Country",
                              hint: "Enter country",
                              icon: FontAwesomeIcons.globe,
                              controller: countryController,
                              validator: (v) =>
                                  v!.isEmpty ? "Required" : null,
                            ),
                            const SizedBox(height: 14),

                            CustomTextField(
                              label: "Province",
                              hint: "Enter province",
                              icon: FontAwesomeIcons.map,
                              controller: provinceController,
                              validator: (v) =>
                                  v!.isEmpty ? "Required" : null,
                            ),

                            const SizedBox(height: 24),

                            PrimaryButton(
                              text: "Register",
                              icon: FontAwesomeIcons.check,
                              onPressed: handleRegister,
                            ),
                            const SizedBox(height: 12),

                            OutlinedButtonWidget(
                              text: "Cancel",
                              icon: FontAwesomeIcons.xmark,
                              onPressed: () {
                                context.push('/login');
                              },
                            ),

                            const SizedBox(height: 18),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Already have an account? "),
                                GestureDetector(
                                  onTap: () {
                                    context.push('/login');
                                  },
                                  child: const Text(
                                    "Login here",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: const [
                                BadgeChip(
                                    icon: FontAwesomeIcons.leaf,
                                    text: "Indigenous Knowledge"),
                                BadgeChip(
                                    icon: FontAwesomeIcons.mobile,
                                    text: "ICT Integration"),
                                BadgeChip(
                                    icon: FontAwesomeIcons.heart,
                                    text: "Conservation"),
                                BadgeChip(
                                    icon: FontAwesomeIcons.users,
                                    text: "Community Based"),
                              ],
                            ),
                          ],
                        ),
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