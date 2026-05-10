// widgets/badge_row.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class BadgeRow extends StatelessWidget {
  const BadgeRow({super.key});

  final List<_Badge> badges = const [
    _Badge(label: "Indigenous Knowledge", icon: Icons.eco),
    _Badge(label: "ICT Integration", icon: Icons.smartphone),
    _Badge(label: "Conservation", icon: Icons.favorite),
    _Badge(label: "Community Based", icon: Icons.group),
    _Badge(label: "Monitoring", icon: Icons.show_chart),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;

      // Determine number of badges per row based on screen width
      int badgesPerRow = 2; // default for mobile
      if (screenWidth >= 600) badgesPerRow = 3;
      if (screenWidth >= 900) badgesPerRow = 4;

      // Calculate width dynamically including spacing
      final spacing = 12.0;
      final totalSpacing = spacing * (badgesPerRow - 1);
      final badgeWidth = (screenWidth - totalSpacing) / badgesPerRow;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        alignment: WrapAlignment.start,
        children: badges.map((badge) {
          return SizedBox(
            width: badgeWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    badge.icon,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      badge.label,
                      textAlign: TextAlign.start,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _Badge {
  final String label;
  final IconData icon;

  const _Badge({required this.label, required this.icon});
}