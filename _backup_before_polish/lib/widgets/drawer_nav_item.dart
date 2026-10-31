import 'package:flutter/material.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:go_router/go_router.dart';

class DrawerNavItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  final bool isActive;

  const DrawerNavItem({
    super.key,
    required this.title,
    required this.icon,
    required this.route,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppColors.primary : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? AppColors.primary : Colors.black87,
        
        ),
      ),
      tileColor:
          isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
      // shape: RoundedRectangleBorder(
      //   borderRadius: BorderRadius.circular(30),
      // ),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}