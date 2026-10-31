// lib/screens/user/plant_detail_screen.dart
// Detail page for a registered species (opened by tapping a species card).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/widgets/responsive_wrap_grid.dart';
import 'package:medplant/widgets/secondary_scaffold.dart';
import '/models/plant_model.dart';

class PlantDetailScreen extends StatelessWidget {
  final PlantModel plant;

  const PlantDetailScreen({super.key, required this.plant});

  bool _has(String? v) => v != null && v.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SecondaryScaffold(
      title: plant.name,
      maxWidth: 800,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header card ─────────────────────────────────────────────
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSoft),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 40, 20, 0.08),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      plant.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : Container(
                                  color: AppColors.accentBg,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.accentBg,
                        child: const Center(
                          child: Icon(Icons.eco,
                              size: 56, color: AppColors.primarySoft),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      children: [
                        Text(
                          plant.name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        if (_has(plant.localName)) ...[
                          const SizedBox(height: 4),
                          Text(
                            plant.localName!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dancingScript(
                                fontSize: 18, color: AppColors.primary),
                          ),
                        ],
                        if (_has(plant.family)) ...[
                          const SizedBox(height: 4),
                          Text(
                            "${plant.family} family",
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                        if (_has(plant.conservationStatus)) ...[
                          const SizedBox(height: 10),
                          _pill(Icons.shield_outlined,
                              plant.conservationStatus!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _infoSection(
              icon: Icons.info_outline,
              title: "Description",
              content: _has(plant.description)
                  ? plant.description!
                  : "No description has been added yet.",
            ),
            const SizedBox(height: 14),
            _infoSection(
              icon: Icons.medical_services_outlined,
              title: "Medicinal Uses",
              content: _has(plant.medicinalUses)
                  ? plant.medicinalUses!
                  : "No medicinal uses have been recorded yet.",
            ),
            const SizedBox(height: 20),

            Text(
              "Species Information",
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 10),
            ResponsiveWrapGrid(
              minItemWidth: 150,
              spacing: 10,
              children: [
                _infoItem("Common Name", plant.commonName),
                _infoItem("Local Name", plant.localName),
                _infoItem("Family", plant.family),
                _infoItem("Genus", plant.genus),
                _infoItem("Parts Used", plant.partsUsed),
                _infoItem("Harvesting Season", plant.harvestingSeason),
                _infoItem("Location", plant.locationArea),
                _infoItem("Conservation", plant.conservationStatus),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.badgeBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(text,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark)),
          ],
        ),
      );

  Widget _infoSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        border: Border(left: BorderSide(color: AppColors.primary, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content,
              style: const TextStyle(
                  height: 1.6, color: AppColors.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String? value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            _has(value) ? value! : "—",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
