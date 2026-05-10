// lib/widgets/info_grid.dart
// Aligned with research proposal — Thaba-Nchu context
// Shows: registered species, degradation contributors (from literature review),
// and IK integration approach

import 'package:flutter/material.dart';
import 'info_card.dart';

class InfoGrid extends StatelessWidget {
  const InfoGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    int columns = 1;
    if (screenWidth >= 600) columns = 2;
    if (screenWidth >= 900) columns = 3;

    final spacing = 16.0;
    final cardWidth = (screenWidth - spacing * (columns - 1) - 32) / columns;

    return Center(
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        alignment: WrapAlignment.start,
        children: [
          SizedBox(
            width: cardWidth,
            child: const InfoCard(
              title: "Registered Species (Thaba-Nchu)",
              icon: Icons.eco,
              type: "check",
              items: [
                "Agapanthus Africanus",
                "Knowltonia Capensis",
                "Lessertia Frutescens",
                "Hypoxis Hemerocallidea",
                "Bulbine Frutescens",
                "And more...",
              ],
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: const InfoCard(
              title: "Degradation Contributors (Literature)",
              icon: Icons.warning,
              type: "times",
              items: [
                "Over-harvesting",
                "Land Use Change",
                "Climate Change",
                "Pollution",
              ],
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: const InfoCard(
              title: "IK Integration (Barolong Community)",
              icon: Icons.psychology,
              type: "indigenous",
              items: [
                "Healer observational indicators",
                "Local damage vocabulary",
                "Traditional harvesting knowledge",
                "Oral monitoring practices",
              ],
            ),
          ),
        ],
      ),
    );
  }
}
