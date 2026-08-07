// widgets/plant_grid.dart
// Uses a Wrap (same pattern as InfoGrid) so each card's height is
// determined by its own content instead of a fixed GridView aspect ratio.
// This removes the dead space below shorter cards and prevents overflow
// on cards with longer descriptions.

import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import 'plant_card.dart';

class PlantGrid extends StatelessWidget {
  final List<PlantModel> plants;

  const PlantGrid({super.key, required this.plants});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine number of columns based on screen width
    int columns = 1; // mobile default
    if (screenWidth >= 600) columns = 2;
    if (screenWidth >= 900) columns = 3;
    if (screenWidth >= 1200) columns = 4;

    final spacing = 12.0;
    // Matches the horizontal padding this widget's parent typically applies
    // (12 on each side, see user_home_screen.dart) — adjust if your
    // surrounding padding differs.
    final outerPadding = 24.0;
    final cardWidth =
        (screenWidth - outerPadding - (spacing * (columns - 1))) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.start,
      children: plants
          .map(
            (plant) => SizedBox(
              width: cardWidth,
              child: PlantCard(plant: plant),
            ),
          )
          .toList(),
    );
  }
}