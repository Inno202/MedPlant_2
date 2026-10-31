// lib/widgets/plant_card.dart
// Displays a registered species card using live Firestore data mapped
// through PlantModel. Shows: image, name, local name, family,
// conservation status badge, health status, description, medicinal uses,
// and harvesting season — no "Read More" tap-through needed.

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
            child: AspectRatio(
              aspectRatio: 1.3, // width : height of the image area
              child: Image.network(
                plant.imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
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
                  color: AppColors.accentBg,
                  child: const Center(
                    child: Icon(Icons.eco,
                        size: 48, color: AppColors.primarySoft),
                  ),
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

                // ── Description ──────────────────────────────────────
                if (plant.description != null &&
                    plant.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.borderSoft),
                  const SizedBox(height: 8),
                  _detailBlock(
                    icon: Icons.info_outline,
                    label: "Description",
                    value: plant.description!,
                    maxLines: 3,
                  ),
                ],

                // ── Medicinal uses ────────────────────────────────────
                if (plant.medicinalUses != null &&
                    plant.medicinalUses!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _detailBlock(
                    icon: Icons.medical_services_outlined,
                    label: "Medicinal Uses",
                    value: plant.medicinalUses!,
                    maxLines: 2,
                  ),
                ],

                // ── Harvesting season ──────────────────────────────────
                if (plant.harvestingSeason != null &&
                    plant.harvestingSeason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                                height: 1.4),
                            children: [
                              const TextSpan(
                                text: "Harvest: ",
                                style:
                                    TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(text: plant.harvestingSeason!),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable label + truncated value block ──────────────────────────────
  Widget _detailBlock({
    required IconData icon,
    required String label,
    required String value,
    required int maxLines,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppColors.primary),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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