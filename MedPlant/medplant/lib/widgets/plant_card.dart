// lib/widgets/plant_card.dart
// Displays a registered species card using live Firestore data mapped
// through PlantModel. Shows: image, name, local name, family,
// conservation status badge, and health status if present.

import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class PlantCard extends StatelessWidget {
  final PlantModel plant;

  const PlantCard({super.key, required this.plant});

  Color _statusColor(String? status) {
    switch (status) {
      case 'Healthy':
        return const Color(0xFF27AE60);
      case 'Stressed':
        return const Color(0xFFF39C12);
      case 'Degraded':
        return const Color(0xFFE74C3C);
      default:
        return AppColors.primary;
    }
  }

  Color _conservationColor(String? status) {
    switch (status) {
      case 'Least Concern':
        return const Color(0xFF27AE60);
      case 'Near Threatened':
        return const Color(0xFF2980B9);
      case 'Vulnerable':
        return const Color(0xFFF39C12);
      case 'Endangered':
        return const Color(0xFFE67E22);
      case 'Critically Endangered':
        return const Color(0xFFE74C3C);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image ───────────────────────────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              plant.imageUrl,
              width: double.infinity,
              height: 280,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 280,
                  color: AppColors.accentBg,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: AppColors.primarySoft,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 280,
                color: AppColors.accentBg,
                child: const Center(
                  child: Icon(Icons.eco,
                      size: 48, color: AppColors.primarySoft),
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  plant.name,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Scientific / common name
                if (plant.scientificName != null &&
                    plant.scientificName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    plant.scientificName!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Local name
                if (plant.localName != null &&
                    plant.localName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.people_outline,
                        size: 11, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        plant.localName!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],

                // Family
                if (plant.family != null &&
                    plant.family!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.account_tree_outlined,
                        size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      plant.family!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                  ]),
                ],

                const SizedBox(height: 8),

                // ── Badges row ──────────────────────────────────────
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Conservation status badge
                    if (plant.conservationStatus != null)
                      _Badge(
                        label: plant.conservationStatus!,
                        color: _conservationColor(
                            plant.conservationStatus),
                      ),

                    // Health status badge (if ML data present)
                    if (plant.healthStatus != null)
                      _Badge(
                        label: plant.healthStatus!,
                        color: _statusColor(plant.healthStatus),
                        icon: plant.healthStatus == 'Degraded'
                            ? Icons.warning_amber_rounded
                            : plant.healthStatus == 'Stressed'
                                ? Icons.trending_down
                                : Icons.check_circle_outline,
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Read More button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.accentBg,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      "Read More",
                      style: GoogleFonts.lato(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small reusable badge ──────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}