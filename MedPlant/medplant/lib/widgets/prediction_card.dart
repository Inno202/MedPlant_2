// lib/widgets/prediction_card.dart
// Displays the combined output of all three Random Forest ML functions:
//   Function 1 – Species Identification (confidence score)
//   Function 2 – Trend-Based Health Classification + trend direction
//   Function 3 – Damage Detection (multi-label)

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/prediction_model.dart';

class PredictionCard extends StatelessWidget {
  final PredictionModel prediction;

  const PredictionCard({super.key, required this.prediction});

  // ── Colour coding for health status (green / amber / red) ──────────────
  Color _healthColor(String status) {
    switch (status) {
      case 'Healthy':
        return const Color(0xFF27AE60);
      case 'Stressed':
        return const Color(0xFFF39C12);
      default:
        return AppColors.primary;
    }
  }

  IconData _trendIcon(String trend) {
    switch (trend) {
      case 'Improving':
        return Icons.trending_up;
      case 'Declining':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  Color _trendColor(String trend) {
    switch (trend) {
      case 'Improving':
        return const Color(0xFF27AE60);
      case 'Declining':
        return const Color(0xFFE74C3C);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthColor = _healthColor(prediction.healthStatus);

    return Container(
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
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(
              child: Icon(prediction.icon, size: 36, color: AppColors.primary),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Species name + location
                  Text(
                    prediction.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          prediction.location,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── ML Function 1: Species ID confidence ────────────────
                  _sectionLabel("ML F1 · Species ID"),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primarySoft],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      "${(prediction.similarity * 100).toInt()}% Confidence",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── ML Function 2: Health Classification + Trend ────────
                  _sectionLabel("ML F2 · Health & Trend"),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: healthColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: healthColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          prediction.healthStatus,
                          style: TextStyle(
                            color: healthColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _trendIcon(prediction.trendDirection),
                        size: 16,
                        color: _trendColor(prediction.trendDirection),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          prediction.trendDirection,
                          style: TextStyle(
                            fontSize: 11,
                            color: _trendColor(prediction.trendDirection),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Based on ${prediction.priorReportCount} prior report${prediction.priorReportCount == 1 ? '' : 's'}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),

                  const SizedBox(height: 10),

                  // ── ML Function 3: Damage Detection ─────────────────────
                  _sectionLabel("ML F3 · Damage Detected"),
                  const SizedBox(height: 4),
                  if (prediction.damageLabels.isEmpty)
                    const Text(
                      "No visible damage detected",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    )
                  else
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: prediction.damageLabels
                          .map((label) => _damageChip(label))
                          .toList(),
                    ),

                  const SizedBox(height: 10),

                  // ── Combined prediction note ─────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        left: BorderSide(color: AppColors.primary, width: 3),
                      ),
                    ),
                    child: Text(
                      prediction.predictionNote,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),

                  // ── Environmental context ────────────────────────────────
                  const SizedBox(height: 8),
                  _factorRow(Icons.thermostat, "Temp", prediction.temperature),
                  _factorRow(Icons.wb_sunny, "Season", prediction.season),
                  _factorRow(Icons.cloud, "Conditions", prediction.environmentalCondition),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.primarySoft,
          letterSpacing: 0.5,
        ),
      );

  Widget _damageChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFFE74C3C),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _factorRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 11, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              "$label: ",
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 10, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}
