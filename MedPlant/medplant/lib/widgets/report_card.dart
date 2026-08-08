// lib/widgets/report_card.dart
// Restyled to match PlantCard: Card widget, AspectRatio image, structured
// detail blocks with icon + label + truncated value. No more fixed image
// height or independent inner scrolling — content drives card height,
// consistent with the Wrap-based ReportGrid.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'dart:convert';
import 'dart:typed_data';

class ReportCard extends StatelessWidget {
  final String? imageUrl;
  final String? imageBase64;

  final String location;
  final String date;
  final String environment;
  final String description;

  const ReportCard({
    super.key,
    this.imageUrl,
    this.imageBase64,
    required this.location,
    required this.date,
    required this.environment,
    required this.description,
  });

  Widget _buildImage() {
    // Base64 image (Firestore)
    if (imageBase64 != null && imageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(imageBase64!);
        return Image.memory(
          Uint8List.fromList(bytes),
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return _errorImage();
      }
    }

    // Network image (fallback or older data)
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
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
        errorBuilder: (context, error, stackTrace) => _errorImage(),
      );
    }

    return _errorImage();
  }

  Widget _errorImage() {
    return Container(
      color: AppColors.accentBg,
      child: const Center(
        child: Icon(Icons.image_not_supported,
            size: 40, color: AppColors.primarySoft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image ───────────────────────────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 1.3,
              child: _buildImage(),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location (title)
                Text(
                  location,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                // Date
                Row(children: [
                  const Icon(Icons.calendar_today,
                      size: 11, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(
                    date,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ]),

                const SizedBox(height: 8),

                // ── Badges row ──────────────────────────────────────
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Badge(
                      label: environment,
                      color: AppColors.primary,
                      icon: Icons.thermostat,
                    ),
                  ],
                ),

                // ── Description ──────────────────────────────────────
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.borderSoft),
                  const SizedBox(height: 8),
                  _detailBlock(
                    icon: Icons.notes,
                    label: "Observation",
                    value: description,
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable label + truncated value block (matches PlantCard) ──────────
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

// ── Small reusable badge (identical to PlantCard's _Badge) ─────────────────
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