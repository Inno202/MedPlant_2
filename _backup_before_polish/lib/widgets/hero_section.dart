// lib/widgets/hero_section.dart
// Aligned with research proposal — Thaba-Nchu medicinal plant monitoring context

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Image.network(
          "https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=1400",
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        ),

        // Dark overlay
        Container(
          height: 250,
          color: Colors.black.withOpacity(0.55),
        ),

        Positioned(
          left: 16,
          right: 16,
          top: 36,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Headline — matches research study title
              Text(
                "Medicinal Plant Monitoring · Thaba-Nchu",
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "... The MedPlant Way ...",
                style: GoogleFonts.dancingScript(
                  color: Colors.white70,
                  fontSize: 17,
                ),
              ),

              const SizedBox(height: 10),

              // Three quick-stat badges
              // Wrap(
              //   spacing: 8,
              //   runSpacing: 6,
              //   children: [
              //     _badge(Icons.eco, "1 Species Registered"),
              //     _badge(Icons.camera_alt, "7 Community Reports"),
              //     _badge(Icons.warning_amber, "2 Active Alerts"),
              //   ],
              // ),

              const SizedBox(height: 14),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () { context.go('/about'); },
                child: Text(
                  "Learn More",
                  style: GoogleFonts.montserrat(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
