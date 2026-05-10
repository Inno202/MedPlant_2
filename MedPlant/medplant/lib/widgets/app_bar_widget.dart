import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  const AppBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primaryDark,
      title: const Text("MedPlants", style: TextStyle(color: AppColors.white)),
      actions: [
        TextButton(
          onPressed: () {
                          context.push('/login');},
          child: const Text("Login", style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () { 
                          context.push('/register');},
          child: const Text("Register", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}