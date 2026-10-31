import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/biodiversity_model.dart';

class BiodiversityCard extends StatelessWidget {
  final BiodiversityModel biodiversity;

  const BiodiversityCard({super.key, required this.biodiversity});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 40, 20, 0.07),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🔥 ICON HEADER (same style as PredictionCard)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Icon(
                biodiversity.mainIcon,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ),

          // 🔥 SCROLLABLE CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE
                  Text(
                    biodiversity.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryDark,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // REGION
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          biodiversity.region,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 🔥 HEALTH INDEX BADGE (same style as similarity)
                  Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primarySoft
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      "${biodiversity.status}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 🔥 FACTORS (same layout as PredictionCard)
                  buildFactor(
                    biodiversity.healthIcon,
                    "Overall Health",
                    "${(biodiversity.healthIndex * 100).toInt()}% (${biodiversity.status})",
                  ),
                  buildFactor(
                    biodiversity.threatIcon,
                    "Threat Level",
                    biodiversity.threatLevel,
                  ),
                  buildFactor(
                    biodiversity.priorityIcon,
                    "Conservation Priority",
                    biodiversity.conservationPriority,
                  ),
                  buildFactor(
                    biodiversity.reportsIcon,
                    "Community Reports",
                    "${biodiversity.reportsThisMonth} this month",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFactor(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "$label: $value",
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}