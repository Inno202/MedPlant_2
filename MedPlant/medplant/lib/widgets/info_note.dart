// lib/widgets/info_note.dart
// Explains the three-function RF ML pipeline to users
// Aligned with research proposal Section 2.3.1 (Components) and Section 7.1

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class InfoNote extends StatelessWidget {
  const InfoNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(
            color: AppColors.primary,
            width: 5,
          ),
        ),
      ),
      // child: Column(
      //   crossAxisAlignment: CrossAxisAlignment.start,
      //   children: const [
      //     InfoRow(
      //       icon: Icons.search,
      //       text:
      //           "ML Function 1 – Species Identification: Random Forest matches the submitted image against the registered Thaba-Nchu medicinal species list and returns a confidence score.",
      //     ),
      //     SizedBox(height: 10),
      //     InfoRow(
      //       icon: Icons.health_and_safety,
      //       text:
      //           "ML Function 2 – Health Classification: Classifies the plant as Healthy, Stressed, or Degraded, then compares results against prior Firebase submissions to produce a trend-based prediction score (Improving / Stable / Declining).",
      //     ),
      //     SizedBox(height: 10),
      //     InfoRow(
      //       icon: Icons.bug_report,
      //       text:
      //           "ML Function 3 – Damage Detection: Identifies specific visible damage indicators — leaf discolouration, wilting, browning, lesions, stem damage. Multiple damage types can be flagged per submission.",
      //     ),
      //     SizedBox(height: 10),
      //     InfoRow(
      //       icon: Icons.psychology,
      //       text:
      //           "IK Integration: Damage detection labels are grounded in Barolong community observational knowledge collected through the Microsoft Forms survey administered to traditional healers in Thaba-Nchu.",
      //     ),
      //   ],
      // ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const InfoRow({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
