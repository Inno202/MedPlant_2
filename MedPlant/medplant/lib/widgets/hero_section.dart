// lib/widgets/hero_section.dart
// Aligned with research proposal — Thaba-Nchu medicinal plant monitoring context.
// Height follows its content (no fixed 250px box), so the text never gets
// clipped on small phones or with larger system font sizes.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/user_role.dart';
import '../providers/user_provider.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  static const _imageUrl =
      "https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=1400";

  @override
  Widget build(BuildContext context) {
    final role = context.select<UserProvider, UserRole?>((u) => u.role);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // Background image fills whatever height the content needs.
          Positioned.fill(
            child: Image.network(
              _imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.primaryDark),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(color: AppColors.primaryDark),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 220),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text("Thaba-Nchu · Free State",
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Medicinal Plant Monitoring",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "... The MedPlant Way ...",
                  style: GoogleFonts.dancingScript(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (role == UserRole.communityUser)
                      ElevatedButton.icon(
                        style: _filled,
                        onPressed: () => context.push('/addreport'),
                        icon: const Icon(Icons.add_a_photo,
                            size: 16, color: AppColors.primaryDark),
                        label: Text("Submit Report",
                            style: GoogleFonts.montserrat(
                                color: AppColors.primaryDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      onPressed: () => context.push('/about'),
                      child: Text(
                        "Learn More",
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static final ButtonStyle _filled = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
  );
}
